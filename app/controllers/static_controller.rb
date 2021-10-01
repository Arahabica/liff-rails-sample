class StaticController < ApplicationController
  skip_before_action :authenticate_user!
  def root
    # 静的ファイルの配信
    render file: 'public/index.html', layout: false, content_type: 'text/html'
  end
end
