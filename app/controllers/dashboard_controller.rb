class DashboardController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!

  def index
    @pagy, @keywords = pagy(current_user.keywords.active_first.includes(:keyword_upload), items: 20)

    # KPIs
    @total_keywords = current_user.keywords.count
    @processed_keywords = current_user.keywords.where.not(status: "pending").count
    @total_uploads = current_user.keyword_uploads.count
    @processing_rate = (@total_keywords > 0) ? (@processed_keywords.to_f / @total_keywords * 100).round(1) : 0

    # Check if we have pending/processing keywords for polling
    @has_pending_keywords = current_user.keywords.where(status: [:pending, :processing]).exists?

    respond_to do |format|
      format.html
      format.json do
        # For JSON requests, only send the current page's keywords for efficiency
        render json: {
          total_keywords: @total_keywords,
          processed_keywords: @processed_keywords,
          total_uploads: @total_uploads,
          processing_rate: @processing_rate,
          has_pending_keywords: @has_pending_keywords,
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
