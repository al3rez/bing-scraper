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

    # Use progress callback to save incremental results after each page
    result = scraper.call(keyword.phrase) do |progress_data|
      # Save partial results after each page is scraped
      keyword.update!(
        ads_count: progress_data[:ads_count],
        links_count: progress_data[:links_count],
        ads_data: progress_data[:ads],
        links_data: progress_data[:links]
      )

      # Store HTML for this page
      if progress_data[:html].present?
        keyword.html_pages.attach(
          io: StringIO.new(progress_data[:html]),
          filename: "#{keyword.phrase.parameterize}-page-#{progress_data[:current_page]}.html",
          content_type: "text/html"
        )
      end
    end

    # Final update with completion status
    keyword.update!(
      ads_count: result.ads_count,
      links_count: result.links_count,
      ads_data: result.ads,
      links_data: result.links,
      scraped_at: Time.current,
      status: :completed,
      error_message: nil
    )

    logger&.info("Processed keyword ##{keyword.id} (#{keyword.phrase})")
  rescue => e
    keyword.update!(status: :failed, error_message: e.message)
    logger&.error("Failed to process keyword ##{keyword.id}: #{e.class} #{e.message}")
  ensure
    # Update processed count immediately after each keyword
    upload.increment!(:processed_keywords_count)
  end
end
