class KeywordResultsQuery
  include Pagy::Backend

  def initialize(keyword, page_params = {})
    @keyword = keyword
    @page = page_params[:page] || 1
    @items_per_page = page_params[:items] || 20
  end

  def call
    combined_results = combine_results
    sorted_results = sort_results(combined_results)
    paginate_results(sorted_results)
  end

  private

  attr_reader :keyword, :page, :items_per_page

  def combine_results
    all_results = []

    ads_data.each do |ad|
      all_results << ad.merge("result_type" => "ad")
    end

    links_data.each do |link|
      result = format_link_result(link)
      all_results << result.merge("result_type" => "organic")
    end

    all_results
  end

  def ads_data
    @ads_data ||= keyword.ads_data || []
  end

  def links_data
    @links_data ||= keyword.links_data || []
  end

  def format_link_result(link)
    return link unless link.is_a?(String)

    {
      "url" => link,
      "title" => link,
      "page" => 1
    }
  end

  def sort_results(results)
    results.sort_by do |result|
      page_number = result["page"] || result[:page] || 1
      result_priority = (result["result_type"] == "ad") ? 0 : 1
      [ page_number, result_priority ]
    end
  end

  def paginate_results(sorted_results)
    pagy_array(sorted_results, items: items_per_page, page: page)
  end
end
