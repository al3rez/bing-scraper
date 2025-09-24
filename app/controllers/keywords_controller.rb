require "pagy/extras/array"

class KeywordsController < ApplicationController
  include ActionView::Helpers::DateHelper
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_keyword, only: [ :show, :download_page ]

  def index
    @keywords = current_user.keywords.recent_first.includes(:keyword_upload)
  end

  def show
    @ads = @keyword.ads_data || []
    @links = @keyword.links_data || []

    # Combine all results for pagination
    all_results = []
    @ads.each { |ad| all_results << ad.merge("result_type" => "ad") }
    @links.each { |link| all_results << (link.is_a?(String) ? { "url" => link, "title" => link, "page" => 1, "result_type" => "organic" } : link.merge("result_type" => "organic")) }

    # Sort by page, then ads first
    sorted_results = all_results.sort_by { |r| [ r["page"] || r[:page] || 1, (r["result_type"] == "ad") ? 0 : 1 ] }

    # Paginate results
    @pagy, @results = pagy_array(sorted_results, items: 20)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: @keyword.status,
          ads_count: @keyword.ads_count,
          links_count: @keyword.links_count,
          ads: @ads,
          links: @links,
          status_text: keyword_status_text(@keyword),
          status_class: keyword_status_class(@keyword)
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
      redirect_to authenticated_root_path, alert: "Keyword not found or access denied." and return
    end
  end

  def keyword_status_text(keyword)
    case keyword.status
    when "pending"
      "Queued"
    when "processing"
      "Scraping..."
    when "completed"
      if keyword.scraped_at
        "Scraped #{time_ago_in_words(keyword.scraped_at)} ago"
      else
        "Completed"
      end
    when "failed"
      "Failed"
    else
      keyword.status.humanize
    end
  end

  def keyword_status_class(keyword)
    case keyword.status
    when "pending"
      "text-xs text-slate-600"
    when "processing"
      "text-xs text-yellow-600"
    when "completed"
      "text-xs text-green-600"
    when "failed"
      "text-xs text-red-600"
    else
      "text-xs text-slate-600"
    end
  end
end
