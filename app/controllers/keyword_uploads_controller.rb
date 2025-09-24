class KeywordUploadsController < ApplicationController
  before_action :authenticate_user!

  def index
    @keyword_upload = KeywordUpload.new
    @keyword_uploads = current_user.keyword_uploads.recent_first.includes(:keywords)
  end

  def create
    file = keyword_upload_params[:file]

    return redirect_to(authenticated_root_path, alert: "Please choose a CSV file to upload.") if file.blank?

    upload = KeywordIngestionService.new(
      user: current_user,
      file_path: file.tempfile.path,
      original_filename: file.original_filename
    ).call
    ProcessKeywordUploadJob.perform_later(upload.id)

    redirect_to authenticated_root_path, notice: "Keywords uploaded! Scraping will begin shortly."
  rescue ArgumentError => e
    redirect_to authenticated_root_path, alert: e.message
  rescue => e
    Rails.logger.error("Keyword upload failed: #{e.class} #{e.message}")
    redirect_to authenticated_root_path, alert: "We couldn't process that file. Please try again."
  end

  private

  def keyword_upload_params
    params.require(:keyword_upload).permit(:file)
  end
end
