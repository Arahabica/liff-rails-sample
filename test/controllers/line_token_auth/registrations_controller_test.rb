require 'test_helper'
require 'mocha/minitest'

class LineTokenAuth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  describe LineTokenAuth::RegistrationsController do

    def mock_registration_params
      {
        uid: Faker::Number.number(digits: 10).to_s,
        access_token: Faker::Number.number(digits: 10).to_s
      }
    end

    describe 'Validate non-empty body' do
      before do
        # need to post empty data
        post '/api/auth', params: {}

        @resource = assigns(:resource)
        @data = JSON.parse(response.body)
      end

      test 'request should fail' do
        assert_equal 422, response.status
      end

      test 'returns error message' do
        assert_not_empty @data['errors']
      end

      test 'return error status' do
        assert_equal 'error', @data['status']
      end

      test 'user should not have been saved' do
        assert @resource.nil?
      end
    end

    describe 'Successful registration' do
      before do
        params = mock_registration_params
        stubs_line_ok('channel_001', params[:uid], 'name001')
        post '/api/auth', params: params

        @resource = assigns(:resource)
        @data = JSON.parse(response.body)
      end

      test 'request should be successful' do
        assert_equal 200, response.status
      end

      test 'user should have been created' do
        assert @resource.id
      end

      test 'user should not be confirmed' do
        assert_nil @resource.confirmed_at
      end

      test 'new user data should be returned as json' do
        assert @data['data']['uid']
      end

      test 'new user password should not be returned' do
        assert_nil @data['data']['password']
      end
    end

    describe 'using allow_unconfirmed_access_for' do
      before do
        @original_duration = Devise.allow_unconfirmed_access_for
        Devise.allow_unconfirmed_access_for = nil
      end

      test 'auth headers were returned in response' do
        params = mock_registration_params
        stubs_line_ok('channel_001', params[:uid], 'name001')
        post '/api/auth', params: params
        assert response.headers['access-token']
        assert response.headers['token-type']
        assert response.headers['client']
        assert response.headers['expiry']
        assert response.headers['uid']
      end

      describe 'using auth cookie' do
        before do
          DeviseTokenAuth.cookie_enabled = true
        end

        test 'auth cookie was returned in response' do
          params = mock_registration_params
          stubs_line_ok('channel_001', params[:uid], 'name001')
          post '/api/auth', params: params
          assert response.cookies[DeviseTokenAuth.cookie_name]
        end

        after do
          DeviseTokenAuth.cookie_enabled = false
        end
      end

      after do
        Devise.allow_unconfirmed_access_for = @original_duration
      end
    end


    describe 'Invalid access token' do
      before do
        params = mock_registration_params
        stubs_line_verify_error('channel_001')
        post '/api/auth', params: params

        @resource = assigns(:resource)
        @data = JSON.parse(response.body)
      end

      test 'request should not be successful' do
        assert_equal 401, response.status
      end

      test 'user should have been created' do
        refute @resource.persisted?
      end

      test 'error should be returned in the response' do
        assert @data['errors'].length
      end
    end

    describe 'Existing users' do
      before do
        @existing_user = create(:user)

        stubs_line_ok('channel_001', @existing_user.uid, 'name001')
        post '/api/auth',
             params: { uid: @existing_user.uid,
                       access_token: 'secret123' }

        @resource = assigns(:resource)
        @data = JSON.parse(response.body)
      end

      test 'request should not be successful' do
        assert_equal 422, response.status
      end

      test 'user should have been created' do
        refute @resource.persisted?
      end

      test 'error should be returned in the response' do
        assert @data['errors'].length
      end
    end

    describe 'Destroy user account' do
      describe 'success' do
        before do
          @existing_user = create(:user)
          @auth_headers  = @existing_user.create_new_auth_token
          @client_id     = @auth_headers['client']

          # ensure request is not treated as batch request
          age_token(@existing_user, @client_id)

          delete '/api/auth', params: {}, headers: @auth_headers

          @data = JSON.parse(response.body)
        end

        test 'request is successful' do
          assert_equal 200, response.status
        end

        test 'message should be returned' do
          assert @data['message']
          assert_equal @data['message'],
                       I18n.t('devise_token_auth.registrations.account_with_uid_destroyed',
                              uid: @existing_user.uid)
        end
        test 'existing user should be deleted' do
          refute User.where(id: @existing_user.id).first
        end
      end

      describe 'failure: no auth headers' do
        before do
          delete '/api/auth'
          @data = JSON.parse(response.body)
        end

        test 'request returns 404 (not found) status' do
          assert_equal 404, response.status
        end

        test 'error should be returned' do
          assert @data['errors'].length
          assert_equal @data['errors'], [I18n.t('devise_token_auth.registrations.account_to_destroy_not_found')]
        end
      end
    end

    describe 'Update user account' do
      describe 'existing user' do
        before do
          @existing_user = create(:user)
          @auth_headers  = @existing_user.create_new_auth_token
          @client_id     = @auth_headers['client']

          # ensure request is not treated as batch request
          age_token(@existing_user, @client_id)
        end
      end
    end

    describe 'Excluded :registrations module' do
      test 'UnregisterableUser should not be able to access registration routes' do
        assert_raises(ActionController::RoutingError) do
          post '/api/unregisterable_user_auth',
               params: { uid: Faker::Number.number(digits: 10).to_s,
                         access_token: 'secret123' }
        end
      end
    end

    def stubs_line_ok(line_channel_id, uid, display_name)
      LineTokenAuth::RegistrationsController.any_instance.stubs(:line_channel_id).returns(line_channel_id)
      LineTokenAuth::RegistrationsController.any_instance.stubs(:verify_line_token).returns({
        code: 200,
        body: {
          client_id: line_channel_id,
          expires_in: 100
        }
      })
      LineTokenAuth::RegistrationsController.any_instance.stubs(:get_profile_by_line_token).returns({
        code: 200,
        body: {
          userId: uid,
          displayName: display_name,
          pictureUrl: 'https://sample.com/sample.png'
        }
      })
    end
    def stubs_line_verify_error(line_channel_id)
      LineTokenAuth::RegistrationsController.any_instance.stubs(:line_channel_id).returns(line_channel_id)
      LineTokenAuth::RegistrationsController.any_instance.stubs(:verify_line_token).returns({
        code: 401,
        body: {
          error: "invalid_request",
          error_description: "invalid token"
        }
      })
    end
  end
end