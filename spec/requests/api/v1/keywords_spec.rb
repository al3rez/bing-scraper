require 'rails_helper'

RSpec.describe 'Api::V1::Keywords', type: :request do
  describe 'GET /api/v1/keywords' do
    context 'when authentication is valid' do
      it 'returns user keywords in active_first order and excludes other user data' do
        user = create(:user)
        other_user = create(:user, email: 'other@example.com')
        keyword_upload = create(:keyword_upload, user: user)

        completed_keyword = create(:keyword,
                                 user: user,
                                 keyword_upload: keyword_upload,
                                 phrase: 'ruby on rails',
                                 status: 'completed',
                                 ads_count: 5,
                                 links_count: 100)

        pending_keyword = create(:keyword,
                                user: user,
                                keyword_upload: keyword_upload,
                                phrase: 'javascript framework',
                                status: 'pending')

        create(:keyword, user: other_user, phrase: 'private keyword')

        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get api_v1_keywords_path, headers: auth_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        keywords = json_response['keywords']

        expect(keywords).to be_an(Array)
        expect(keywords.length).to eq(2)
        expect(keywords.first['phrase']).to eq('ruby on rails')
        expect(keywords.first['status']).to eq('completed')
        expect(keywords.first['ads_count']).to eq(5)
        expect(keywords.first['links_count']).to eq(100)
        expect(keywords.second['phrase']).to eq('javascript framework')
        expect(keywords.second['status']).to eq('pending')

        keyword_phrases = keywords.map { |k| k['phrase'] }
        expect(keyword_phrases).not_to include('private keyword')
      end

      it 'includes all expected keyword attributes' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        create(:keyword, user: user, keyword_upload: keyword_upload, phrase: 'test keyword')

        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get api_v1_keywords_path, headers: auth_headers

        json_response = JSON.parse(response.body)
        keyword = json_response['keywords'].first

        expect(keyword).to have_key('id')
        expect(keyword).to have_key('phrase')
        expect(keyword).to have_key('status')
        expect(keyword).to have_key('ads_count')
        expect(keyword).to have_key('links_count')
        expect(keyword).to have_key('upload_filename')
        expect(keyword).to have_key('created_at')
        expect(keyword).to have_key('updated_at')
      end
    end

    context 'when authentication is missing' do
      it 'returns unauthorized error' do
        get api_v1_keywords_path

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Unauthorized')
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized error' do
        headers = { 'Authorization' => 'Bearer invalid_token' }

        get api_v1_keywords_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when token is expired' do
      it 'returns unauthorized error' do
        user = create(:user)
        expired_token = generate_jwt_token(user, exp: 1.hour.ago.to_i)
        headers = { 'Authorization' => "Bearer #{expired_token}" }

        get api_v1_keywords_path, headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/keywords/:id' do
    context 'when authentication is valid and keyword exists' do
      it 'returns keyword details' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        completed_keyword = create(:keyword,
                                 user: user,
                                 keyword_upload: keyword_upload,
                                 phrase: 'ruby on rails',
                                 status: 'completed',
                                 ads_count: 5,
                                 links_count: 100)

        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get api_v1_keyword_path(completed_keyword), headers: auth_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        keyword = json_response['keyword']

        expect(keyword['id']).to eq(completed_keyword.id)
        expect(keyword['phrase']).to eq('ruby on rails')
        expect(keyword['status']).to eq('completed')
        expect(keyword['ads_count']).to eq(5)
        expect(keyword['links_count']).to eq(100)
        expect(keyword).to have_key('has_html_pages')
      end
    end

    context 'when keyword does not exist' do
      it 'returns not found error' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get api_v1_keyword_path(99999), headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Not found')
      end
    end

    context 'when trying to access another user\'s keyword' do
      it 'returns not found error' do
        user = create(:user)
        other_user = create(:user, email: 'other@example.com')
        other_user_keyword = create(:keyword, user: other_user, phrase: 'private keyword')

        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get api_v1_keyword_path(other_user_keyword), headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authentication is missing' do
      it 'returns unauthorized error' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        completed_keyword = create(:keyword, user: user, keyword_upload: keyword_upload)

        get api_v1_keyword_path(completed_keyword)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/keywords/:id/search_results' do
    context 'when authentication is valid and completed keyword exists' do
      it 'returns keyword and search results data' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        completed_keyword = create(:keyword,
                                 user: user,
                                 keyword_upload: keyword_upload,
                                 phrase: 'ruby on rails',
                                 status: 'completed',
                                 ads_count: 5,
                                 links_count: 100)

        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get search_results_api_v1_keyword_path(completed_keyword), headers: auth_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('keyword')
        expect(json_response).to have_key('search_results')

        keyword = json_response['keyword']
        expect(keyword['id']).to eq(completed_keyword.id)
        expect(keyword['phrase']).to eq('ruby on rails')

        search_results = json_response['search_results']
        expect(search_results['ads_count']).to eq(5)
        expect(search_results['links_count']).to eq(100)
        expect(search_results).to have_key('html_pages_count')
      end
    end

    context 'when keyword does not exist' do
      it 'returns not found error' do
        user = create(:user)
        jwt_token = generate_jwt_token(user)
        auth_headers = { 'Authorization' => "Bearer #{jwt_token}" }

        get search_results_api_v1_keyword_path(99999), headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authentication is missing' do
      it 'returns unauthorized error' do
        user = create(:user)
        keyword_upload = create(:keyword_upload, user: user)
        completed_keyword = create(:keyword, user: user, keyword_upload: keyword_upload)

        get search_results_api_v1_keyword_path(completed_keyword)

        expect(response).to have_http_status(:unauthorized)
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
