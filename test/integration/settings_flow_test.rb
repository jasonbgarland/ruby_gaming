require "test_helper"

class SettingsFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  test "requires authentication" do
    get settings_path
    assert_redirected_to new_session_path
  end

  test "shows current values" do
    sign_in(@user)
    get settings_path
    assert_response :success
    assert_match @user.first_name, response.body
    assert_match @user.last_name, response.body
    assert_match @user.username, response.body
    assert_match @user.email_address, response.body
    assert_no_match "password1234", response.body
  end

  test "profile update success" do
    sign_in(@user)
    patch settings_path, params: { user: { first_name: "Updated", last_name: @user.last_name, username: @user.username, email_address: @user.email_address } }
    assert_redirected_to settings_path
    assert_equal "Updated", @user.reload.first_name
  end

  test "profile update with own unchanged email allowed" do
    sign_in(@user)
    patch settings_path, params: { user: { first_name: "NewName", last_name: @user.last_name, username: @user.username, email_address: @user.email_address } }
    assert_redirected_to settings_path
    assert_equal "NewName", @user.reload.first_name
  end

  test "profile update rejects another user's email" do
    sign_in(@user)
    other = users(:two)
    patch settings_path, params: { user: { first_name: @user.first_name, last_name: @user.last_name, username: @user.username, email_address: other.email_address } }
    assert_response :unprocessable_entity
    assert_match "Email address has already been taken", response.body
    assert_not_equal other.email_address, @user.reload.email_address
  end

  test "password change success" do
    sign_in(@user)
    patch settings_password_path, params: { user: { password_challenge: "password1234", password: "newpassword1234", password_confirmation: "newpassword1234" } }
    assert_redirected_to settings_path

    post session_path, params: { identifier: @user.email_address, password: "newpassword1234" }
    assert_redirected_to root_path

    post session_path, params: { identifier: @user.email_address, password: "password1234" }
    assert_redirected_to new_session_path
  end

  test "password change with wrong current password" do
    sign_in(@user)
    digest_before = @user.password_digest
    patch settings_password_path, params: { user: { password_challenge: "wrongpassword", password: "newpassword1234", password_confirmation: "newpassword1234" } }
    assert_response :unprocessable_entity
    assert_equal digest_before, @user.reload.password_digest
  end

  test "password change with blank current password" do
    sign_in(@user)
    digest_before = @user.password_digest
    patch settings_password_path, params: { user: { password_challenge: "", password: "newpassword1234", password_confirmation: "newpassword1234" } }
    assert_response :unprocessable_entity
    assert_match "can&#39;t be blank", response.body
    assert_equal digest_before, @user.reload.password_digest
  end

  test "password change with mismatched confirmation" do
    sign_in(@user)
    digest_before = @user.password_digest
    patch settings_password_path, params: { user: { password_challenge: "password1234", password: "newpassword1234", password_confirmation: "different1234" } }
    assert_response :unprocessable_entity
    assert_equal digest_before, @user.reload.password_digest
  end

  test "password change with too short new password" do
    sign_in(@user)
    digest_before = @user.password_digest
    patch settings_password_path, params: { user: { password_challenge: "password1234", password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
    assert_equal digest_before, @user.reload.password_digest
  end
end
