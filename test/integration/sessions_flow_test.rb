require "test_helper"

class SessionsFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "login by email" do
    assert_difference("Session.count", 1) do
      post session_path, params: { identifier: @user.email_address, password: "password1234" }
    end
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "login by username" do
    assert_difference("Session.count", 1) do
      post session_path, params: { identifier: @user.username, password: "password1234" }
    end
    assert_redirected_to root_path
  end

  test "login email is case insensitive" do
    post session_path, params: { identifier: @user.email_address.upcase, password: "password1234" }
    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "login with wrong password" do
    assert_no_difference("Session.count") do
      post session_path, params: { identifier: @user.email_address, password: "wrongpassword" }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Try another username/email or password.", response.body
  end

  test "login with unknown identifier" do
    assert_no_difference("Session.count") do
      post session_path, params: { identifier: "doesnotexist@example.com", password: "password1234" }
    end
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Try another username/email or password.", response.body
  end

  test "logout" do
    sign_in(@user)
    assert_difference("Session.count", -1) do
      delete session_path
    end
    assert_redirected_to new_session_path
    assert_response :see_other

    get settings_path
    assert_redirected_to new_session_path
  end

  test "persistent session cookie" do
    sign_in(@user)
    assert cookies[:session_id]
    assert_equal 1, @user.sessions.count

    get settings_path
    assert_response :success
  end

  test "login is rate limited" do
    cache = ActiveSupport::Cache::MemoryStore.new
    original_cache = Rails.cache
    Rails.cache = cache

    begin
      10.times do
        post session_path, params: { identifier: @user.email_address, password: "wrongpassword" }
        assert_redirected_to new_session_path
        follow_redirect!
        assert_match "Try another username/email or password.", response.body
      end

      post session_path, params: { identifier: @user.email_address, password: "wrongpassword" }
      assert_redirected_to new_session_path
      follow_redirect!
      assert_match "Try again later.", response.body
    ensure
      Rails.cache = original_cache
    end
  end
end
