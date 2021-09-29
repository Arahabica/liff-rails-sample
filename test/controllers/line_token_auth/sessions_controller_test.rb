require "test_helper"
require 'mocha/minitest'

class LineTokenAuth::SessionsControllerTest < ActionController::TestCase
  describe LineTokenAuth::SessionsController do
    describe 'Existing user' do
      before do
        @existing_user = create(:user, :with_nickname)
      end

      describe 'success' do
        before do
          stubs_line_ok('channel_001', @existing_user.uid, 'name001')
          @user_session_params = {
            uid: @existing_user.uid,
            access_token: 'token001'
          }

          post :create, params: @user_session_params
          @resource = assigns(:resource)
          @data = JSON.parse(response.body)
        end

        test 'request should succeed' do
          assert_equal 200, response.status
        end
        test 'request should return user data' do
          assert_equal @existing_user.uid, @data['data']['uid']
        end
        describe 'using auth cookie' do
          before do
            DeviseTokenAuth.cookie_enabled = true
          end

          test 'request should return auth cookie' do
            post :create, params: @user_session_params
            assert response.cookies[DeviseTokenAuth.cookie_name]
          end

          after do
            DeviseTokenAuth.cookie_enabled = false
          end
        end

        describe "with multiple clients and headers don't change in each request" do
          before do
            # Set the max_number_of_devices to a lower number
            #  to expedite tests! (Default is 10)
            DeviseTokenAuth.max_number_of_devices = 2
            DeviseTokenAuth.change_headers_on_each_request = false
          end

          test 'should limit the maximum number of concurrent devices' do
            # increment the number of devices until the maximum is exceeded
            1.upto(DeviseTokenAuth.max_number_of_devices + 1).each do |n|
              initial_tokens = @existing_user.reload.tokens

              assert_equal(
                [n, DeviseTokenAuth.max_number_of_devices].min,
                @existing_user.reload.tokens.length
              )

              # Already have the max number of devices
              post :create, params: @user_session_params

              # A session for a new device maintains the max number of concurrent devices
              refute_equal initial_tokens, @existing_user.reload.tokens
            end
          end

          test 'should drop old tokens when max number of devices is exceeded' do
            1.upto(DeviseTokenAuth.max_number_of_devices).each do |n|
              post :create, params: @user_session_params
            end

            oldest_token, _ = @existing_user.reload.tokens \
                                .min_by { |cid, v| v[:expiry] || v['expiry'] }

            post :create, params: @user_session_params

            assert_not_includes @existing_user.reload.tokens.keys, oldest_token
          end

          after do
            DeviseTokenAuth.max_number_of_devices = 10
            DeviseTokenAuth.change_headers_on_each_request = true
          end
        end
      end
      describe 'get sign_in is not supported' do
        before do
          stubs_line_ok('channel_001', @existing_user.uid, 'name001')
          get :new,
              params: { uid: @existing_user.uid,
                        access_token: 'token001' }
          @data = JSON.parse(response.body)
        end

        test 'user is notified that they should use post sign_in to authenticate' do
          assert_equal 405, response.status
        end
        test 'response should contain errors' do
          assert @data['errors']
          assert_equal @data['errors'], [I18n.t('devise_token_auth.sessions.not_supported')]
        end
      end
      describe 'header sign_in is supported' do
        before do
          stubs_line_ok('channel_001', @existing_user.uid, 'name001')
          request.headers.merge!(
            'uid' => @existing_user.uid,
            'access_token' => 'token001'
          )

          head :create
          @data = JSON.parse(response.body)
        end

        test 'user can sign in using header request' do
          assert_equal 200, response.status
        end
      end


      describe 'authed user sign out' do
        before do
          def @controller.reset_session_called
            @reset_session_called == true
          end

          def @controller.reset_session
            @reset_session_called = true
          end
          @auth_headers = @existing_user.create_new_auth_token
          request.headers.merge!(@auth_headers)
          delete :destroy, format: :json
        end

        test 'user is successfully logged out' do
          assert_equal 200, response.status
        end

        test 'token was destroyed' do
          @existing_user.reload
          refute @existing_user.tokens[@auth_headers['client']]
        end

        test 'session was destroyed' do
          assert_equal true, @controller.reset_session_called
        end

        describe 'using auth cookie' do
          before do
            DeviseTokenAuth.cookie_enabled = true
            @auth_token = @existing_user.create_new_auth_token
            @controller.send(:cookies)[DeviseTokenAuth.cookie_name] = { value: @auth_token.to_json }
          end

          test 'auth cookie was destroyed' do
            assert_equal @auth_token.to_json, @controller.send(:cookies)[DeviseTokenAuth.cookie_name] # sanity check
            delete :destroy, format: :json
            assert_nil @controller.send(:cookies)[DeviseTokenAuth.cookie_name]
          end

          after do
            DeviseTokenAuth.cookie_enabled = false
          end
        end
      end

      describe 'unauthed user sign out' do
        before do
          @auth_headers = @existing_user.create_new_auth_token
          delete :destroy, format: :json
          @data = JSON.parse(response.body)
        end

        test 'unauthed request returns 404' do
          assert_equal 404, response.status
        end

        test 'response should contain errors' do
          assert @data['errors']
          assert_equal @data['errors'],
                       [I18n.t('devise_token_auth.sessions.user_not_found')]
        end
      end

      describe 'failure' do
        before do
          stubs_line_verify_error('channel_001')
          post :create,
               params: { uid: @existing_user.uid,
                         access_token: 'bogus' }

          @resource = assigns(:resource)
          @data = JSON.parse(response.body)
        end

        test 'request should fail' do
          assert_equal 401, response.status
        end

        test 'response should contain errors' do
          assert @data['errors']
          assert_equal @data['errors'],
                       ['invalid token']
        end
      end
    end
    describe 'Non-existing user' do
      describe 'failure' do
        before do
          post :create,
               params: { uid: -> { Faker::Number.number(10) },
                         access_token: -> { Faker::Number.number(10) } }
          @resource = assigns(:resource)
          @data = JSON.parse(response.body)
        end

        test 'request should fail' do
          assert_equal 401, response.status
        end

        test 'response should contain errors' do
          assert @data['errors']
        end
      end
    end
    def stubs_line_ok(line_channel_id, uid, display_name)
      LineTokenAuth::SessionsController.any_instance.stubs(:line_channel_id).returns(line_channel_id)
      LineTokenAuth::SessionsController.any_instance.stubs(:verify_line_token).returns({
        code: 200,
        body: {
          client_id: line_channel_id,
          expires_in: 100
        }
      })
      LineTokenAuth::SessionsController.any_instance.stubs(:get_profile_by_line_token).returns({
        code: 200,
        body: {
          userId: uid,
          displayName: display_name,
          pictureUrl: 'https://sample.com/sample.png'
        }
      })
    end
    def stubs_line_verify_error(line_channel_id)
      LineTokenAuth::SessionsController.any_instance.stubs(:line_channel_id).returns(line_channel_id)
      LineTokenAuth::SessionsController.any_instance.stubs(:verify_line_token).returns({
        code: 401,
        body: {
          error: "invalid_request",
          error_description: "invalid token"
        }
      })
    end
  end
end
