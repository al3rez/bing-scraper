class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @keyword_uploads = current_user.keyword_uploads.recent_first.limit(5)
    @recent_keywords = current_user.keywords.recent_first.limit(10)
  end
end
