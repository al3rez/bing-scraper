# frozen_string_literal: true

require "digest"
require "stringio"

class KeywordUploadProcessor
  def initialize(upload:, scraper: Scrapers::BingKeywordScraper.new, logger: Rails.logger)
    @upload = upload
    @scraper = scraper
    @logger = logger
  end

  def call
    upload.with_lock do
      upload.status_processing!
      upload.update!(processed_keywords_count: 0, error_message: nil, processed_at: nil)
    end

    upload.keywords.order(:created_at).each do |keyword|
      process_keyword(keyword)
    end

    upload.with_lock do
      upload.update!(processed_at: Time.current)
      upload.status_completed!
    end
  rescue => e
    upload.with_lock do
      upload.update!(error_message: e.message, processed_at: Time.current)
      upload.status_failed!
    end
    raise
  ensure
    scraper.close
  end

  private

  attr_reader :upload, :scraper, :logger

  def process_keyword(keyword)
    keyword.status_processing!

    result = scraper.call(keyword.phrase)

    keyword.transaction do
      attach_html(keyword, result.html)
      keyword.update!(
        ads_count: result.ads_count,
        links_count: result.links_count,
        scraped_at: Time.current,
        serp_digest: digest_for(result.html),
        status: :completed,
        error_message: nil
      )
    end

    logger&.info("Processed keyword ##{keyword.id} (#{keyword.phrase})")
  rescue => e
    keyword.update!(status: :failed, error_message: e.message)
    logger&.error("Failed to process keyword ##{keyword.id}: #{e.class} #{e.message}")
  ensure
    upload.increment!(:processed_keywords_count)
  end

  def attach_html(keyword, html)
    return if html.blank?

    keyword.serp_html.attach(
      io: StringIO.new(html),
      filename: "keyword-#{keyword.id}-#{Time.current.to_i}.html",
      content_type: "text/html"
    )
  end

  def digest_for(html)
    return nil if html.blank?

    Digest::SHA256.hexdigest(html)
  end
end
