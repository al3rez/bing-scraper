require "pagy/extras/array"

class KeywordsController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_keyword, only: [ :show, :download_page ]

  def index
    @keywords = current_user.keywords.recent_first.includes(:keyword_upload)
  end

  def show
    @ads = @keyword.ads_data || []
    @links = @keyword.links_data || []
    @pagy, @results = keyword_results_query.call

    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: @keyword.status,
          ads_count: @keyword.ads_count,
          links_count: @keyword.links_count,
          ads: @ads,
          links: @links,
          status_text: keyword_presenter.status_text,
          status_class: keyword_presenter.status_class
        }
      end
    end
  end

  def download_page
    page_attachment = @keyword.html_pages.find(params[:page_id])
    send_data page_attachment.download,
      filename: page_attachment.filename.to_s,
      type: "text/html"
  rescue ActiveRecord::RecordNotFound
    redirect_to @keyword, alert: "Page not found"
  end

  private

  def set_keyword
    @keyword = current_user.keywords.find_by(id: params[:id])

    if @keyword.nil?
      redirect_to authenticated_root_path,
                  alert: "Keyword not found or access denied." and return
    end
  end

  def keyword_presenter
    @keyword_presenter ||= KeywordPresenter.new(@keyword)
  end

  def keyword_results_query
    @keyword_results_query ||= KeywordResultsQuery.new(
      @keyword,
      page: params[:page]
    )
  end
end
