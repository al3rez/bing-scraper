class DashboardQuery
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def call
    {
      total_keywords: total_keywords,
      processed_keywords: processed_keywords,
      total_uploads: total_uploads,
      processing_rate: processing_rate,
      has_pending_keywords: has_pending_keywords?
    }
  end

  private

  def total_keywords
    @total_keywords ||= user.keywords.count
  end

  def processed_keywords
    @processed_keywords ||= user.keywords.where.not(status: "pending").count
  end

  def total_uploads
    @total_uploads ||= user.keyword_uploads.count
  end

  def processing_rate
    return 0 if total_keywords.zero?

    (processed_keywords.to_f / total_keywords * 100).round(1)
  end

  def has_pending_keywords?
    @has_pending_keywords ||= user.keywords.where(status: [ :pending, :processing ]).exists?
  end
end
