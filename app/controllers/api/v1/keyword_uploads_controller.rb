class Api::V1::KeywordUploadsController < Api::V1::BaseController
  def create
    file = params[:file]

    if file.blank?
      return render json: { error: "No file provided" }, status: :bad_request
    end

    begin
      validate_file!(file)

      upload = KeywordIngestionService.new(
        user: current_user,
        file_path: file.tempfile.path,
        original_filename: file.original_filename
      ).call

      ProcessKeywordUploadJob.perform_later(upload.id)

      render json: {
        message: "Keywords uploaded successfully! Scraping will begin shortly.",
        upload: {
          id: upload.id,
          original_filename: upload.original_filename,
          keywords_count: upload.keywords.count,
          created_at: upload.created_at
        }
      }, status: :created

    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    rescue => e
      Rails.logger.error("API Keyword upload failed: #{e.class} #{e.message}")
      render json: { error: "We couldn't process that file. Please try again." }, status: :internal_server_error
    end
  end

  private

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
