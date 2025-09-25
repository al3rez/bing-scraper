class Api::V1::AuthenticationController < Api::V1::BaseController
  # Skip authentication for sign_in endpoint
  skip_before_action :authenticate_user!, only: [ :sign_in ]

  def sign_in
    user = User.find_by(email: sign_in_params[:email])

    if user&.valid_password?(sign_in_params[:password])
      token = generate_jwt_token(user)
      render json: {
        token: token,
        user: {
          id: user.id,
          email: user.email
        }
      }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end

  private

  def sign_in_params
    params.require(:user).permit(
      :email,
      :password
    )
  end

  def generate_jwt_token(user)
    payload = {
      user_id: user.id,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end
end
