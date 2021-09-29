ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"
require 'minitest/rails'

require 'database_cleaner'

DEVISE_TOKEN_AUTH_ORM = (ENV['DEVISE_TOKEN_AUTH_ORM'] || :active_record).to_sym

#FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
#FactoryBot.find_definitions

class ActiveSupport::TestCase

  include FactoryBot::Syntax::Methods

  ActiveRecord::Migration.check_pending! if DEVISE_TOKEN_AUTH_ORM == :active_record

  strategies = { active_record: :transaction, mongoid: :deletion }
  DatabaseCleaner.strategy = strategies[DEVISE_TOKEN_AUTH_ORM]
  setup { DatabaseCleaner.start }
  teardown { DatabaseCleaner.clean }


  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    #@routes = Dummy::Application.routes
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end
end

def age_token(user, client_id)
  if user.tokens[client_id]
    user.tokens[client_id]['updated_at'] = (Time.zone.now - (DeviseTokenAuth.batch_request_buffer_throttle + 10.seconds))
    user.save!
  end
end

def expire_token(user, client_id)
  if user.tokens[client_id]
    user.tokens[client_id]['expiry'] = (Time.zone.now - (DeviseTokenAuth.token_lifespan.to_f + 10.seconds)).to_i
    user.save!
  end
end