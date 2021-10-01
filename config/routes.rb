Rails.application.routes.draw do
  root to: 'staitc#root'
  scope '/api' do
    mount_devise_token_auth_for 'User', at: 'auth', controllers: {
      registrations: 'line_token_auth/registrations',
      sessions: 'line_token_auth/sessions'
    }

    get '/config/liff_id', to: 'config#liff_id'
    get '/me', to: 'sessions#me'
  end
end
