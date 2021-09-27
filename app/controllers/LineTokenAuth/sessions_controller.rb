module LineTokenAuth
  class SessionsController < DeviseTokenAuth::SessionsController

    def create
      # Check
      field = (resource_params.keys.map(&:to_sym) & resource_class.authentication_keys).first
      @resource = nil
      if field
        q_value = get_case_insensitive_field_from_resource_params(field)
        @resource = find_resource(field, q_value)
      end
      
      if @resource && valid_params?(field, q_value) && (!@resource.respond_to?(:active_for_authentication?) || @resource.active_for_authentication?)
        #valid_password = @resource.valid_password?(resource_params[:password])
        #if (@resource.respond_to?(:valid_for_authentication?) && !@resource.valid_for_authentication? { valid_password }) || !valid_password
        #  return render_create_error_bad_credentials
        #end
        user_params = authenticate(field, resource_params[:access_token])
        valid_token = !!user_params
        if (@resource.respond_to?(:valid_for_authentication?) && !@resource.valid_for_authentication? { valid_token }) || !valid_token
          return render_create_error_bad_credentials
        end
        
        @token = @resource.create_token
        @resource.save
      
        sign_in(:user, @resource, store: false, bypass: false)
      
        yield @resource if block_given?
      
        render_create_success
      elsif @resource && !(!@resource.respond_to?(:active_for_authentication?) || @resource.active_for_authentication?)
        if @resource.respond_to?(:locked_at) && @resource.locked_at
          render_create_error_account_locked
        else
          render_create_error_not_confirmed
        end
      else
        user_params = authenticate(field, resource_params[:access_token])
        if !user_params
          render_create_error_bad_credentials
        end
      end
    end
    def valid_params?(key, val)
      resource_params[:access_token] && key && val
    end
    def provider
      'line'
    end
    private
    def authenticate(uid, access_token)
      if access_token == 'token001'
        {
          uid: uid,
          name: 'myname',
          image: 'image_url'
        }
      else
        nil
      end
    end
  end
end
