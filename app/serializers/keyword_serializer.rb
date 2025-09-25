class KeywordSerializer
  include JSONAPI::Serializer

  attributes :phrase, :status, :ads_count, :links_count,
             :scraped_at, :created_at, :updated_at

  attribute :upload_filename do |keyword|
    keyword.keyword_upload_original_filename
  end

  attribute :has_html_pages do |keyword|
    keyword.html_pages.attached?
  end

  belongs_to :keyword_upload
end
