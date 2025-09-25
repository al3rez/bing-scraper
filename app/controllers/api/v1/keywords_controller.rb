class Api::V1::KeywordsController < Api::V1::BaseController
  # callbacks
  before_action :find_keyword, only: [ :show, :search_results ]

  # public instance methods
  def index
    keywords = current_user.keywords.includes(:keyword_upload).active_first

    render json: {
      keywords: keywords.map do |keyword|
        {
          id: keyword.id,
          phrase: keyword.phrase,
          status: keyword.status,
          ads_count: keyword.ads_count,
          links_count: keyword.links_count,
          upload_filename: keyword.keyword_upload_original_filename,
          created_at: keyword.created_at,
          updated_at: keyword.updated_at
        }
      end
    }
  end

  def show
    render json: {
      keyword: {
        id: @keyword.id,
        phrase: @keyword.phrase,
        status: @keyword.status,
        ads_count: @keyword.ads_count,
        links_count: @keyword.links_count,
        upload_filename: @keyword.keyword_upload_original_filename,
        created_at: @keyword.created_at,
        updated_at: @keyword.updated_at,
        has_html_pages: @keyword.html_pages.attached?
      }
    }
  end

  def search_results
    render json: {
      keyword: {
        id: @keyword.id,
        phrase: @keyword.phrase,
        status: @keyword.status,
        ads_count: @keyword.ads_count,
        links_count: @keyword.links_count,
        upload_filename: @keyword.keyword_upload_original_filename,
        created_at: @keyword.created_at,
        updated_at: @keyword.updated_at
      },
      search_results: {
        ads_count: @keyword.ads_count,
        links_count: @keyword.links_count,
        html_pages_count: @keyword.html_pages.count
      }
    }
  end

  private

  def find_keyword
    @keyword = current_user.keywords.find(params[:id])
  end
end
