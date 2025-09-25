require 'rails_helper'

RSpec.describe 'Dashboard', type: :request do
  describe 'GET /dashboard' do
    context 'when user is authenticated' do
      it 'displays dashboard with KPIs and keywords' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        completed_keyword = create(:keyword,
                                 user: user,
                                 keyword_upload: keyword_upload,
                                 phrase: 'ruby programming',
                                 status: 'completed',
                                 ads_count: 5,
                                 links_count: 100)
        pending_keyword = create(:keyword,
                               user: user,
                               keyword_upload: keyword_upload,
                               phrase: 'javascript framework',
                               status: 'pending')

        sign_in user
        get authenticated_root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('ruby programming')
        expect(response.body).to include('javascript framework')
      end

      it 'calculates correct KPIs' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'keyword 1', status: 'completed')
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'keyword 2', status: 'completed')
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'keyword 3', status: 'pending')

        sign_in user
        get authenticated_root_path

        expect(assigns(:total_keywords)).to eq(3)
        expect(assigns(:processed_keywords)).to eq(2)
        expect(assigns(:total_uploads)).to eq(1)
        expect(assigns(:processing_rate)).to eq(66.7)
      end

      it 'handles empty state correctly' do
        user = create(:user)

        sign_in user
        get authenticated_root_path

        expect(response).to have_http_status(:ok)
        expect(assigns(:total_keywords)).to eq(0)
        expect(assigns(:processed_keywords)).to eq(0)
        expect(assigns(:processing_rate)).to eq(0)
      end

      it 'detects pending keywords correctly' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'pending keyword', status: 'pending')

        sign_in user
        get authenticated_root_path

        expect(assigns(:has_pending_keywords)).to be(true)
      end

      it 'detects no pending keywords' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'completed keyword', status: 'completed')

        sign_in user
        get authenticated_root_path

        expect(assigns(:has_pending_keywords)).to be(false)
      end
    end

    context 'when requested as JSON' do
      it 'returns dashboard data as JSON' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        keyword = create(:keyword,
                        user: user,
                        keyword_upload: keyword_upload,
                        phrase: 'test keyword',
                        status: 'completed',
                        ads_count: 3,
                        links_count: 50)

        sign_in user
        get authenticated_root_path, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('total_keywords')
        expect(json_response).to have_key('processed_keywords')
        expect(json_response).to have_key('total_uploads')
        expect(json_response).to have_key('processing_rate')
        expect(json_response).to have_key('has_pending_keywords')
        expect(json_response).to have_key('keywords')

        expect(json_response['keywords']).to be_an(Array)
        expect(json_response['keywords'].first).to have_key('id')
        expect(json_response['keywords'].first).to have_key('phrase')
        expect(json_response['keywords'].first).to have_key('status')
        expect(json_response['keywords'].first).to have_key('ads_count')
        expect(json_response['keywords'].first).to have_key('links_count')
      end

      it 'includes scraped_at timestamp when available' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        scraped_time = Time.current
        keyword = create(:keyword,
                        user: user,
                        keyword_upload: keyword_upload,
                        phrase: 'test keyword',
                        status: 'completed',
                        scraped_at: scraped_time)

        sign_in user
        get authenticated_root_path, headers: { 'Accept' => 'application/json' }

        json_response = JSON.parse(response.body)
        expect(json_response['keywords'].first['scraped_at']).to eq(scraped_time.iso8601)
      end
    end

    context 'when user is not authenticated' do
      it 'shows sign in page when accessing root' do
        get "/"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('sign_in') # or whatever the sign in form includes
      end
    end
  end
end
