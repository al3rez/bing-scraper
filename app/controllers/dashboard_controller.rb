class DashboardController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!

  def index
    # Pagination works for both HTML and JSON requests
    @pagy, @keywords = pagy(current_user.keywords.active_first.includes(:keyword_upload), items: 20)

    # Dashboard statistics
    dashboard_stats = DashboardQuery.new(current_user).call
    @total_keywords = dashboard_stats[:total_keywords]
    @processed_keywords = dashboard_stats[:processed_keywords]
    @total_uploads = dashboard_stats[:total_uploads]
    @processing_rate = dashboard_stats[:processing_rate]
    @has_pending_keywords = dashboard_stats[:has_pending_keywords]

    respond_to do |format|
      format.html
      format.json do
        # For JSON requests, send the current page's keywords (respects pagination)
        render json: {
          total_keywords: @total_keywords,
          processed_keywords: @processed_keywords,
          total_uploads: @total_uploads,
          processing_rate: @processing_rate,
          has_pending_keywords: @has_pending_keywords,
          current_page: @pagy.page,
          total_pages: @pagy.pages,
          keywords: @keywords.map do |keyword|
            {
              id: keyword.id,
              phrase: keyword.phrase,
              status: keyword.status,
              ads_count: keyword.ads_count,
              links_count: keyword.links_count,
              scraped_at: keyword.scraped_at&.iso8601,
              keyword_upload_original_filename: keyword.keyword_upload_original_filename
            }
          end
        }
      end
    end
  end
end
