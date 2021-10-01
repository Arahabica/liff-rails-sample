class ConfigController < ApplicationController
  skip_before_action :authenticate_user!
  def liff_id
    render json: { liff_id: ENV["LIFF_ID"]}, status: :ok
  end
end
