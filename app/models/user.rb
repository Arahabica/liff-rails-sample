# frozen_string_literal: true

class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  include DeviseTokenAuth::Concerns::User
  validates_uniqueness_of :uid, conditions: -> { where(provider: 'line') }

  def password_required?
    super && provider != "line"
  end

  def email_required?
    super && provider != "line"
  end
end
