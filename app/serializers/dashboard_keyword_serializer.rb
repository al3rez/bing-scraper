class DashboardKeywordSerializer
  include JSONAPI::Serializer

  attributes :phrase, :status, :ads_count, :links_count

  attribute :scraped_at do |keyword|
    keyword.scraped_at&.iso8601
  end

  attribute :keyword_upload_original_filename do |keyword|
    keyword.keyword_upload_original_filename
  end
end
