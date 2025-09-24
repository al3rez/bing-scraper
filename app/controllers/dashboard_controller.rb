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
  end
end
