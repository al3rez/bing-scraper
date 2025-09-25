require 'rails_helper'

RSpec.describe 'Api::V1::Authentication', type: :request do
  describe 'POST /api/v1/auth/sign_in' do
    context 'when credentials are valid' do
      it 'returns a JWT token and user info' do
        user = create(:user, email: 'test@example.com', password: 'password123')
        valid_params = {
          user: {
            email: user.email,
            password: 'password123'
          }
        }

        post api_v1_auth_sign_in_path, params: valid_params, as: :json

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('token')
        expect(json_response['token']).to be_present
        expect(json_response['user']['id']).to eq(user.id)
        expect(json_response['user']['email']).to eq(user.email)
      end

      it 'returns a valid JWT token' do
        user = create(:user, email: 'test@example.com', password: 'password123')
        valid_params = {
          user: {
            email: user.email,
            password: 'password123'
          }
        }

        post api_v1_auth_sign_in_path, params: valid_params, as: :json

        json_response = JSON.parse(response.body)
        token = json_response['token']
        decoded_token = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })

        expect(decoded_token.first['user_id']).to eq(user.id)
        expect(decoded_token.first['exp']).to be > Time.current.to_i
      end
    end

    context 'when email is invalid' do
      it 'returns unauthorized error' do
        create(:user, email: 'test@example.com', password: 'password123')
        invalid_params = {
          user: {
            email: 'wrong@example.com',
            password: 'password123'
          }
        }

        post api_v1_auth_sign_in_path, params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid credentials')
      end
    end

    context 'when password is invalid' do
      it 'returns unauthorized error' do
        user = create(:user, email: 'test@example.com', password: 'password123')
        invalid_params = {
          user: {
            email: user.email,
            password: 'wrong_password'
          }
        }

        post api_v1_auth_sign_in_path, params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid credentials')
      end
    end

    context 'when parameters are missing' do
      it 'returns unauthorized error when email is missing' do
        invalid_params = { user: { password: 'password123' } }

        post api_v1_auth_sign_in_path, params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid credentials')
      end

      it 'returns unauthorized error when password is missing' do
        invalid_params = { user: { email: 'test@example.com' } }

        post api_v1_auth_sign_in_path, params: invalid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Invalid credentials')
      end
    end

    context 'when request body is malformed' do
      it 'returns bad request error when user object is missing' do
        post api_v1_auth_sign_in_path, params: { email: 'test@example.com' }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end