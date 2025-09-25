class KeywordUploadForm
  include ActiveModel::Model

  attr_accessor :user, :file, :original_filename

  validates :user, presence: true
  validates :file, presence: { message: "Please select a CSV file" }
  validate :validate_file_format
  validate :validate_file_size

  MAX_FILE_SIZE = 5.megabytes

  def initialize(user, params = {})
    @user = user
    super(params)
  end

  def save
    return false unless valid?

    begin
      upload = KeywordIngestionService.new(
        user: user,
        file_path: file.path,
        original_filename: original_filename || file.original_filename
      ).call

      ProcessKeywordUploadJob.perform_later(upload.id)
      @upload = upload
      true
    rescue ArgumentError => e
      errors.add(:file, e.message)
      false
    rescue StandardError => e
      errors.add(:base, "An error occurred while processing your file")
      Rails.logger.error "KeywordUploadForm error: #{e.message}"
      false
    end
  end

  def upload
    @upload
  end

  private

  def validate_file_format
    return unless file

    unless file.respond_to?(:original_filename) && file.original_filename&.downcase&.ends_with?(".csv")
      errors.add(:file, "File must be a CSV file")
    end
  end

  def validate_file_size
    return unless file

    if file.respond_to?(:size) && file.size > MAX_FILE_SIZE
      errors.add(:file, "File size must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end
end
