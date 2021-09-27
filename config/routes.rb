Rails.application.routes.draw do
  scope '/api' do
    mount_devise_token_auth_for 'User', at: 'auth', skip: [:registrations], controllers: {
      sessions: 'line_token_auth/sessions'
    }

    get '/me', to: 'sessions#me'
  end
end
