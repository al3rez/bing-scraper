class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable

  has_many :keyword_uploads, dependent: :destroy, inverse_of: :user
  has_many :keywords, dependent: :destroy, inverse_of: :user
end
