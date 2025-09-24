require "digest"
require "stringio"

class ProcessKeywordJob < ApplicationJob
  queue_as :default

  def perform(keyword_id)
    keyword = Keyword.find_by(id: keyword_id)
    return unless keyword

    keyword.status_processing!

    scraper = Scrapers::BingKeywordScraper.new

    begin
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

      Rails.logger&.info("Processed keyword ##{keyword.id} (#{keyword.phrase})")
    rescue => e
      keyword.update!(status: :failed, error_message: e.message)
      Rails.logger&.error("Failed to process keyword ##{keyword.id}: #{e.class} #{e.message}")
    ensure
      scraper.close
      # Update processed count on the upload
      keyword.keyword_upload&.increment!(:processed_keywords_count)
    end
  end

  private
end
