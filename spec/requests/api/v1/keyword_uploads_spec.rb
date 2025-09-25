require 'rails_helper'

RSpec.describe 'Api::V1::KeywordUploads', type: :request do

  describe 'POST /api/v1/keyword_uploads' do
    context 'when authentication is valid and CSV file is valid' do
      it 'successfully uploads and processes the file' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test_keywords.csv')

        expect do
          post api_v1_keyword_uploads_path,
               params: { file: uploaded_file },
               headers: auth_headers
        end.to have_enqueued_job(ProcessKeywordUploadJob)

        expect(response).to have_http_status(:created)
        json_response = JSON.parse(response.body)
        expect(json_response['message']).to eq('Keywords uploaded successfully! Scraping will begin shortly.')

        upload_data = json_response['upload']
        expect(upload_data['original_filename']).to eq('test_keywords.csv')
        expect(upload_data['keywords_count']).to be > 0
        expect(upload_data).to have_key('id')
        expect(upload_data).to have_key('created_at')

        upload = user.keyword_uploads.last
        expect(upload).to be_present
        expect(upload.original_filename).to eq('test_keywords.csv')

        csv_file.close!
      end

      it 'creates keywords in the database' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test_keywords.csv')

        expect do
          post api_v1_keyword_uploads_path,
               params: { file: uploaded_file },
               headers: auth_headers
        end.to change(user.keywords, :count).by_at_least(1)

        csv_file.close!
      end
    end

    context 'when file parameter is missing' do
      it 'returns bad request error' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        post api_v1_keyword_uploads_path,
             params: {},
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('No file provided')
      end
    end

    context 'when file is too large' do
      it 'returns bad request error' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        large_file = Tempfile.new(['large_keywords', '.csv'])
        # Create a file just over 5MB (5MB = 5,242,880 bytes)
        large_content = "keyword\n" + ("x" * 5242880) + "\n"
        large_file.write(large_content)
        large_file.rewind

        large_uploaded_file = Rack::Test::UploadedFile.new(
          large_file.path, 'text/csv', original_filename: 'large_keywords.csv'
        )

        post api_v1_keyword_uploads_path,
             params: { file: large_uploaded_file },
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('File size must be less than')

        large_file.close!
      end
    end

    context 'when CSV file is invalid' do
      it 'returns bad request error for non-CSV file' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        text_file = Tempfile.new(['test', '.txt'])
        text_file.write('This is not a CSV file')
        text_file.rewind

        text_uploaded_file = Rack::Test::UploadedFile.new(
          text_file.path, 'text/plain', original_filename: 'test.txt'
        )

        post api_v1_keyword_uploads_path,
             params: { file: text_uploaded_file },
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('CSV')

        text_file.close!
      end

      it 'returns bad request error for empty CSV file' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        empty_file = Tempfile.new(['empty', '.csv'])
        empty_file.write('')
        empty_file.rewind

        empty_uploaded_file = Rack::Test::UploadedFile.new(
          empty_file.path, 'text/csv', original_filename: 'empty.csv'
        )

        post api_v1_keyword_uploads_path,
             params: { file: empty_uploaded_file },
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('CSV')

        empty_file.close!
      end

      it 'returns bad request error for invalid CSV structure' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        invalid_file = Tempfile.new(['invalid', '.csv'])
        invalid_file.write("   \n   \n   ")
        invalid_file.rewind

        invalid_uploaded_file = Rack::Test::UploadedFile.new(
          invalid_file.path, 'text/csv', original_filename: 'invalid.csv'
        )

        post api_v1_keyword_uploads_path,
             params: { file: invalid_uploaded_file },
             headers: auth_headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('CSV data')

        invalid_file.close!
      end
    end

    context 'when authentication is missing' do
      it 'returns unauthorized error' do
        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test_keywords.csv')

        post api_v1_keyword_uploads_path,
             params: { file: uploaded_file }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')

        csv_file.close!
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized error' do
        headers = { 'Authorization' => 'Bearer invalid_token' }

        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test_keywords.csv')

        post api_v1_keyword_uploads_path,
             params: { file: uploaded_file },
             headers: headers

        expect(response).to have_http_status(:unauthorized)

        csv_file.close!
      end
    end

    context 'when service raises unexpected error' do
      it 'returns internal server error' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        allow(KeywordIngestionService).to receive(:new).and_raise(StandardError.new('Unexpected error'))

        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        uploaded_file = Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test_keywords.csv')

        post api_v1_keyword_uploads_path,
             params: { file: uploaded_file },
             headers: auth_headers

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq("We couldn't process that file. Please try again.")

        csv_file.close!
      end
    end
  end

  private

  def generate_jwt_token(user, exp: 24.hours.from_now.to_i)
    payload = {
      user_id: user.id,
      exp: exp
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end