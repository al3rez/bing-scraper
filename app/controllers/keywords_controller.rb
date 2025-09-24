class KeywordsController < ApplicationController
  before_action :authenticate_user!

  def index
    @keywords = current_user.keywords.recent_first.includes(:keyword_upload)
  end
end
