class KeywordUploadsController < ApplicationController
  before_action :authenticate_user!

  def index
    @keyword_upload = KeywordUpload.new
    @keyword_uploads = current_user.keyword_uploads.recent_first.includes(:keywords)
  end

  def validate
    file = params[:file]

    if file.blank?
      return render json: { valid: false, error: "No file provided" }
    end

    begin
      validate_file!(file)

      # Count keywords using the service
      service = KeywordIngestionService.new(
        user: current_user,
        file_path: file.tempfile.path,
        original_filename: file.original_filename
      )

      # Extract phrases to count them without saving
      phrases = service.send(:extract_phrases)

      render json: {
        valid: true,
        keyword_count: phrases.size,
        filename: file.original_filename
      }
    rescue ArgumentError => e
      render json: { valid: false, error: e.message }
    rescue => e
      Rails.logger.error("File validation failed: #{e.class} #{e.message}")
      render json: { valid: false, error: "Invalid file format" }
    end
  end

  def create
    form = KeywordUploadForm.new(current_user, keyword_upload_params)

    if form.save
      redirect_to authenticated_root_path, notice: "Keywords uploaded! Scraping will begin shortly."
    else
      @keyword_upload = KeywordUpload.new
      @keyword_uploads = current_user.keyword_uploads.recent_first.includes(:keywords)
      flash.now[:alert] = form.errors.full_messages.join(", ")
      render :index, status: :unprocessable_content
    end
  end

  private

  def keyword_upload_params
    params.require(:keyword_upload).permit(:file)
  end

  def validate_file!(file)
    # File size validation (5MB max to prevent memory issues)
    max_file_size = 5.megabytes
    if file.size > max_file_size
      raise ArgumentError, "File size must be less than #{max_file_size / 1.megabyte}MB"
    end

    # Content type validation
    allowed_types = %w[text/csv text/plain application/csv]
    unless allowed_types.include?(file.content_type) || file.original_filename&.end_with?(".csv")
      raise ArgumentError, "File must be a CSV format"
    end

    # Basic CSV structure validation using first few lines
    validate_csv_structure!(file)
  end

  def validate_csv_structure!(file)
    # Read only first 1KB to check CSV structure without loading entire file
    file.rewind
    sample = file.read(1024)
    file.rewind

    # Check if it contains valid CSV-like content
    lines = sample.split("\n").first(5) # Check first 5 lines max

    if lines.empty?
      raise ArgumentError, "File appears to be empty"
    end

    # Basic validation: should have some comma-separated or single-column data
    valid_lines = lines.count { |line| line.strip.present? && (line.include?(",") || line.split.size == 1) }

    if valid_lines < 1
      raise ArgumentError, "File doesn't appear to contain valid CSV data"
    end
  rescue => e
    raise ArgumentError, "Invalid CSV file: #{e.message}"
  end
end
