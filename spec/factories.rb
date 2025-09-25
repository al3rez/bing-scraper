FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "test#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end

  factory :keyword_upload do
    user
    original_filename { "test.csv" }
    status { "queued" }
    keyword_count { 1 }
    processed_keywords_count { 0 }
  end

  factory :keyword do
    user
    keyword_upload
    phrase { "test keyword" }
    status { "pending" }
    ads_count { 0 }
    links_count { 0 }
  end
end
