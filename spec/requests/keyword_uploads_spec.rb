require 'rails_helper'

RSpec.describe 'KeywordUploads', type: :request do
  let(:user) { User.create!(email: 'uploader@example.com', password: 'password123') }

  describe 'POST /keyword_uploads' do
    context 'when uploading a CSV file' do
      it 'enqueues processing job and persists metadata' do
        sign_in(user)

        expect do
          post keyword_uploads_path, params: {
            keyword_upload: {
              file: Rack::Test::UploadedFile.new(
                Rails.root.join('spec/fixtures/files/keywords.csv'),
                'text/csv'
              )
            }
          }
        end.to have_enqueued_job(ProcessKeywordUploadJob)

        expect(response).to redirect_to(keyword_uploads_path)

        upload = user.keyword_uploads.last
        expect(upload).to be_present
        expect(upload.original_filename).to eq('keywords.csv')
        expect(upload.keyword_count).to eq(2)
        expect(upload.status_queued?).to be(true)
      end
    end

    context 'when file is blank' do
      it 'redirects with an alert' do
        sign_in(user)

        post keyword_uploads_path, params: {keyword_upload: {file: nil}}

        expect(response).to redirect_to(keyword_uploads_path)
        expect(flash[:alert]).to eq('Please choose a CSV file to upload.')
      end
    end

    context 'when ingestion validation fails' do
      it 'surfaces the validation error' do
        sign_in(user)

        empty_file = Tempfile.new(%w[keywords .csv])
        empty_file.write(" \n ")
        empty_file.rewind

        post keyword_uploads_path, params: {
          keyword_upload: {
            file: Rack::Test::UploadedFile.new(empty_file.path, 'text/csv')
          }
        }

        expect(response).to redirect_to(keyword_uploads_path)
        expect(flash[:alert]).to match('No keywords found')
      ensure
        empty_file&.close!
      end
    end
  end
end
