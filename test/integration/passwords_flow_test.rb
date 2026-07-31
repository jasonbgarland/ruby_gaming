require "test_helper"

class PasswordsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { @user = users(:one) }

  test "reset request for existing email sends one email" do
    perform_enqueued_jobs do
      post passwords_path, params: { email_address: @user.email_address }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Password reset instructions sent", response.body

    deliveries = ActionMailer::Base.deliveries.select { |m| m.to.include?(@user.email_address) }
    assert_equal 1, deliveries.size
  end

  test "reset request for unknown email sends no email" do
    perform_enqueued_jobs do
      post passwords_path, params: { email_address: "unknown@example.com" }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Password reset instructions sent", response.body
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  test "reset via valid token" do
    token = @user.password_reset_token

    get edit_password_path(token)
    assert_response :success

    patch password_path(token), params: { password: "newpassword1234", password_confirmation: "newpassword1234" }
    assert_redirected_to new_session_path

    post session_path, params: { identifier: @user.email_address, password: "newpassword1234" }
    assert_redirected_to root_path
  end

  test "reset with invalid token" do
    get edit_password_path("garbage-token")
    assert_redirected_to new_password_path
    follow_redirect!
    assert_match "invalid or has expired", response.body
  end

  test "reset with expired token" do
    token = @user.password_reset_token
    travel 16.minutes do
      get edit_password_path(token)
      assert_redirected_to new_password_path
      follow_redirect!
      assert_match "invalid or has expired", response.body
    end
  end
end
