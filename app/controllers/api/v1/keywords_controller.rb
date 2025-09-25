class Api::V1::KeywordsController < Api::V1::BaseController
  # callbacks
  before_action :find_keyword, only: [ :show, :search_results ]

  # public instance methods
  def index
    keywords = current_user.keywords.includes(:keyword_upload).active_first

    render json: {
      keywords: keywords.map do |keyword|
        KeywordSerializer.new(keyword).serializable_hash[:data][:attributes].merge(id: keyword.id)
      end
    }
  end

  def show
    render json: {
      keyword: KeywordSerializer.new(@keyword).serializable_hash[:data][:attributes].merge(id: @keyword.id)
    }
  end

  def search_results
    data = KeywordSearchResultsSerializer.new(@keyword).serializable_hash[:data][:attributes]
    render json: {
      keyword: data.except(:search_results).merge(id: @keyword.id),
      search_results: data[:search_results]
    }
  end

  private

  def find_keyword
    @keyword = current_user.keywords.find(params[:id])
  end
end
