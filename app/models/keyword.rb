class Keyword < ApplicationRecord
  STATUSES = {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }.freeze

  belongs_to :user, inverse_of: :keywords
  belongs_to :keyword_upload, inverse_of: :keywords

  has_many_attached :html_pages

  enum :status, STATUSES, prefix: :status

  validates :phrase, presence: true
  validates :ads_count, :links_count, numericality: {greater_than_or_equal_to: 0, only_integer: true}

  before_validation :normalize_phrase

  scope :recent_first, -> { order(created_at: :desc) }
  scope :active_first, -> {
    order(
      Arel.sql("CASE status
        WHEN #{STATUSES[:processing]} THEN 1
        WHEN #{STATUSES[:completed]} THEN 0
        WHEN #{STATUSES[:pending]} THEN 2
        WHEN #{STATUSES[:failed]} THEN 3
        ELSE 4 END"),
      :id
    )
  }
  scope :completed, -> { status_completed }

  delegate :original_filename, to: :keyword_upload, prefix: true

  private

  def normalize_phrase
    self.phrase = phrase.to_s.strip
  end
end
