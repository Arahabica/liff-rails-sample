class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  before_action :authenticate_user!, unless: :devise_controller?

  skip_before_action :verify_authenticity_token, if: :devise_controller? # skip CSRF check if API
end
