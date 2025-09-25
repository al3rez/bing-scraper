class DashboardKeywordSerializer
  include JSONAPI::Serializer

  attributes :status, :ads_count, :links_count

  attribute :phrase do |keyword|
    ActionController::Base.helpers.sanitize(keyword.phrase)
  end

  attribute :scraped_at do |keyword|
    keyword.scraped_at&.iso8601
  end

  attribute :keyword_upload_original_filename do |keyword|
    ActionController::Base.helpers.sanitize(keyword.keyword_upload_original_filename)
  end
end
