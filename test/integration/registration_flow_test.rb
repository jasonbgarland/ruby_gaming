require "test_helper"

class RegistrationFlowTest < ActionDispatch::IntegrationTest
  def valid_params(overrides = {})
    {
      first_name: "New",
      last_name: "User",
      username: "newuser",
      email_address: "newuser@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    }.merge(overrides)
  end

  test "signup success" do
    assert_difference("User.count", 1) do
      assert_difference("Session.count", 1) do
        post registration_path, params: { user: valid_params }
      end
    end

    assert_redirected_to root_path
    assert cookies[:session_id]

    follow_redirect!
    assert_select "a", text: "Log out", count: 0
    assert_match "Log out", response.body
  end

  test "signup duplicate email" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(email_address: users(:one).email_address.upcase, username: "brandnewname") }
    end
    assert_response :unprocessable_entity
    assert_match "Email address has already been taken", response.body
  end

  test "signup duplicate username" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(username: users(:one).username, email_address: "someoneelse@example.com") }
    end
    assert_response :unprocessable_entity
    assert_match "Username has already been taken", response.body
  end

  test "signup bad email" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(email_address: "not-an-email") }
    end
    assert_response :unprocessable_entity
    assert_match "Email address is invalid", response.body
  end

  test "signup short password" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(password: "short", password_confirmation: "short") }
    end
    assert_response :unprocessable_entity
    assert_match "too short", response.body
  end

  test "signup password mismatch" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(password_confirmation: "different1234") }
    end
    assert_response :unprocessable_entity
    assert_match "Password confirmation doesn&#39;t match Password", response.body
  end

  test "signup username too long" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(username: "a" * 21) }
    end
    assert_response :unprocessable_entity
    assert_match "Username is too long (maximum is 20 characters)", response.body
  end

  test "signup username bad characters" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(username: "bad*name!") }
    end
    assert_response :unprocessable_entity
    assert_match "Username", response.body
  end

  test "signup missing first name" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: valid_params(first_name: "") }
    end
    assert_response :unprocessable_entity
    assert_match "First name can&#39;t be blank", response.body
  end

  test "root shows login and signup links when logged out" do
    get root_path
    assert_response :success
    assert_match "Log in", response.body
    assert_match "Sign up", response.body
  end

  test "root shows settings and logout when logged in" do
    sign_in(users(:one))
    get root_path
    assert_response :success
    assert_match "Settings", response.body
    assert_match "Log out", response.body
    assert_no_match "Sign up", response.body
  end
end
