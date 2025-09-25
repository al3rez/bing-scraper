require "rails_helper"

RSpec.describe "KeywordUploads", type: :request do
  describe "GET /keyword_uploads" do
    context "when user is authenticated" do
      it "displays keyword uploads index" do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user, original_filename: "test.csv")

        sign_in user
        get keyword_uploads_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("test.csv")
        expect(assigns(:keyword_uploads)).to include(keyword_upload)
        expect(assigns(:keyword_upload)).to be_a_new(KeywordUpload)
      end

      it "orders uploads by most recent first" do
        user = create(:user)
        old_upload = create(:keyword_upload, user: user, original_filename: "old.csv", created_at: 2.days.ago)
        new_upload = create(:keyword_upload, user: user, original_filename: "new.csv", created_at: 1.day.ago)

        sign_in user
        get keyword_uploads_path

        expect(assigns(:keyword_uploads).first).to eq(new_upload)
        expect(assigns(:keyword_uploads).last).to eq(old_upload)
      end

      it "only shows current user uploads" do
        user = create(:user)
        other_user = create(:user, email: 'other@example.com')
        user_upload = create(:keyword_upload, user: user, original_filename: "user.csv")
        other_upload = create(:keyword_upload, user: other_user, original_filename: "other.csv")

        sign_in user
        get keyword_uploads_path

        expect(assigns(:keyword_uploads)).to include(user_upload)
        expect(assigns(:keyword_uploads)).not_to include(other_upload)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get keyword_uploads_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /keyword_uploads/validate" do
    context "when user is authenticated" do
      it "validates CSV file successfully" do
        user = create(:user)
        sign_in user

        csv_file = Tempfile.new(['test_keywords', '.csv']).tap do |file|
          file.write("keyword\nruby on rails\njavascript\nvue.js\n")
          file.rewind
        end

        post validate_keyword_uploads_path, params: {
          file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test.csv')
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be(true)
        expect(json_response['keyword_count']).to be > 0
        expect(json_response['filename']).to eq('test.csv')

        csv_file.close!
      end

      it "returns error for missing file" do
        user = create(:user)
        sign_in user

        post validate_keyword_uploads_path, params: {}

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be(false)
        expect(json_response['error']).to eq('No file provided')
      end

      it "returns error for file too large" do
        user = create(:user)
        sign_in user

        large_file = Tempfile.new(['large_keywords', '.csv'])
        large_content = "keyword\n" + ("x" * 5242881) # Just over 5MB
        large_file.write(large_content)
        large_file.rewind

        post validate_keyword_uploads_path, params: {
          file: Rack::Test::UploadedFile.new(large_file.path, 'text/csv', original_filename: 'large.csv')
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be(false)
        expect(json_response['error']).to include('File size must be less than')

        large_file.close!
      end

      it "returns error for invalid CSV file" do
        user = create(:user)
        sign_in user

        invalid_file = Tempfile.new(['invalid', '.txt'])
        invalid_file.write("This is not a CSV file")
        invalid_file.rewind

        post validate_keyword_uploads_path, params: {
          file: Rack::Test::UploadedFile.new(invalid_file.path, 'text/plain', original_filename: 'invalid.txt')
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be(false)
        expect(json_response['error']).to include('Invalid CSV file')

        invalid_file.close!
      end

      it "handles service errors gracefully" do
        user = create(:user)
        sign_in user

        csv_file = Tempfile.new(['test', '.csv'])
        csv_file.write("keyword\ntest\n")
        csv_file.rewind

        allow(KeywordIngestionService).to receive(:new).and_raise(StandardError.new("Service error"))

        post validate_keyword_uploads_path, params: {
          file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test.csv')
        }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['valid']).to be(false)
        expect(json_response['error']).to eq('Invalid file format')

        csv_file.close!
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post validate_keyword_uploads_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /keyword_uploads" do
    context "when uploading a CSV file" do
      it "enqueues processing job and persists metadata" do
        user = User.create!(email: "uploader@example.com", password: "password123")
        sign_in(user)

        expect do
          post keyword_uploads_path, params: {
            keyword_upload: {
              file: Rack::Test::UploadedFile.new(
                Rails.root.join("spec/fixtures/files/keywords.csv"),
                "text/csv"
              )
            }
          }
        end.to have_enqueued_job(ProcessKeywordUploadJob)

        expect(response).to redirect_to(authenticated_root_path)

        upload = user.keyword_uploads.last
        expect(upload).to be_present
        expect(upload.original_filename).to eq("keywords.csv")
        expect(upload.keyword_count).to eq(51)
        expect(upload.status_queued?).to be(true)
      end
    end

    context "when file is blank" do
      it "redirects with an alert" do
        user = User.create!(email: "uploader@example.com", password: "password123")
        sign_in(user)

        post keyword_uploads_path, params: { keyword_upload: { file: nil } }

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to eq("Please choose a CSV file to upload.")
      end
    end

    context "when ingestion validation fails" do
      it "surfaces the validation error" do
        user = User.create!(email: "uploader@example.com", password: "password123")
        sign_in(user)

        empty_file = Tempfile.new(%w[keywords .csv])
        empty_file.write(" \n ")
        empty_file.rewind

        post keyword_uploads_path, params: {
          keyword_upload: {
            file: Rack::Test::UploadedFile.new(empty_file.path, "text/csv")
          }
        }

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to match("Invalid CSV file: File doesn't appear to contain valid CSV data")

        # Cleanup
        empty_file.close!
      end
    end

    context "when file is too large" do
      it "returns file size error" do
        user = create(:user)
        sign_in user

        large_file = Tempfile.new(['large_keywords', '.csv'])
        large_content = "keyword\n" + ("x" * 5242881) # Just over 5MB
        large_file.write(large_content)
        large_file.rewind

        post keyword_uploads_path, params: {
          keyword_upload: {
            file: Rack::Test::UploadedFile.new(large_file.path, 'text/csv', original_filename: 'large.csv')
          }
        }

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to include('File size must be less than')

        large_file.close!
      end
    end

    context "when file has wrong content type" do
      it "returns format error" do
        user = create(:user)
        sign_in user

        text_file = Tempfile.new(['test', '.txt'])
        text_file.write("This is not a CSV")
        text_file.rewind

        post keyword_uploads_path, params: {
          keyword_upload: {
            file: Rack::Test::UploadedFile.new(text_file.path, 'text/plain', original_filename: 'test.txt')
          }
        }

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to include('Invalid CSV file')

        text_file.close!
      end
    end

    context "when service raises unexpected error" do
      it "returns generic error message" do
        user = create(:user)
        sign_in user

        csv_file = Tempfile.new(['test', '.csv'])
        csv_file.write("keyword\ntest\n")
        csv_file.rewind

        allow(KeywordIngestionService).to receive(:new).and_raise(StandardError.new("Unexpected error"))

        post keyword_uploads_path, params: {
          keyword_upload: {
            file: Rack::Test::UploadedFile.new(csv_file.path, 'text/csv', original_filename: 'test.csv')
          }
        }

        expect(response).to redirect_to(authenticated_root_path)
        expect(flash[:alert]).to eq("We couldn't process that file. Please try again.")

        csv_file.close!
      end
    end
  end
end
