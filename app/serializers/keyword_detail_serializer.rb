class KeywordDetailSerializer
  include JSONAPI::Serializer

  attributes :status, :ads_count, :links_count

  attribute :ads do |keyword|
    keyword.ads_data || []
  end

  attribute :links do |keyword|
    keyword.links_data || []
  end

  attribute :status_text do |keyword|
    KeywordPresenter.new(keyword).status_text
  end

  attribute :status_class do |keyword|
    KeywordPresenter.new(keyword).status_class
  end
end
