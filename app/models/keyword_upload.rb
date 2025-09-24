class KeywordUpload < ApplicationRecord
  STATUSES = {
    queued: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }.freeze

  belongs_to :user, inverse_of: :keyword_uploads
  has_many :keywords, dependent: :destroy, inverse_of: :keyword_upload

  enum :status, STATUSES, prefix: :status

  validates :original_filename, presence: true
  validates :keyword_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :processed_keywords_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  scope :recent_first, -> { order(created_at: :desc) }

  def progress_ratio
    return 0.0 if keyword_count.zero?

    processed_keywords_count.to_f / keyword_count
  end

  def progress_percent
    (progress_ratio * 100).round
  end
end
