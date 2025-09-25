class KeywordUploadSerializer
  include JSONAPI::Serializer

  attributes :original_filename, :keyword_count, :processed_keywords_count,
             :status, :created_at, :updated_at

  has_many :keywords
end
