ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module SignInTestHelper
  # Signs in via a real POST to /session so the cookie/session path is
  # exercised end-to-end rather than stubbed.
  def sign_in(user, password: "password1234")
    post session_path, params: { identifier: user.email_address, password: password }
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SignInTestHelper
end
