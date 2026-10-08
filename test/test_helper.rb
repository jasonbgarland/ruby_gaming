ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require_relative "test_helpers/session_test_helper"

# Block real network calls by default; allow_localhost keeps Capybara/Selenium
# system tests working against the local server and driver.
WebMock.disable_net_connect!(allow_localhost: true)

# Fake IGDB credentials so tests never depend on config/master.key (absent in
# CI). All IGDB HTTP is stubbed, so the values only need to be non-blank.
Rails.application.credentials.igdb = {
  client_id: "test-client-id",
  client_secret: "test-client-secret"
}

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers.
    #
    # macOS + Homebrew's Postgres build (which links Kerberos/GSSAPI) can
    # deadlock when Rails forks parallel test workers after the `pg` gem
    # has opened a connection — the child processes inherit non-fork-safe
    # global state and hang rather than erroring. This doesn't reproduce
    # on Linux/CI Postgres, so parallelization is only disabled locally on
    # macOS; other platforms keep the default one-worker-per-core behavior.
    parallelize(workers: RUBY_PLATFORM.include?("darwin") ? 1 : :number_of_processors)

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
