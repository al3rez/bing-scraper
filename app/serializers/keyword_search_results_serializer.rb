class KeywordSearchResultsSerializer
  include JSONAPI::Serializer

  attributes :phrase, :status, :ads_count, :links_count,
             :scraped_at, :created_at, :updated_at

  attribute :upload_filename do |keyword|
    keyword.keyword_upload_original_filename
  end

  attribute :search_results do |keyword|
    {
      ads_count: keyword.ads_count,
      links_count: keyword.links_count,
      html_pages_count: keyword.html_pages.count,
      ads: keyword.ads_data || [],
      links: keyword.links_data || []
    }
  end
end
