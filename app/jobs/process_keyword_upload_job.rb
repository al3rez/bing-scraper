class ProcessKeywordUploadJob < ApplicationJob
  queue_as :default

  def perform(upload_id)
    upload = KeywordUpload.find_by(id: upload_id)
    return unless upload

    KeywordUploadProcessor.new(upload: upload).call
  end
end
