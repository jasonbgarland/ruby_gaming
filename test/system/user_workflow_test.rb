require "application_system_test_case"

class UserWorkflowTest < ApplicationSystemTestCase
  test "full signup, session, and logout workflow" do
    visit root_path
    assert_text "Log in"
    assert_text "Sign up"

    click_on "Sign up", match: :first

    fill_in "First name", with: "Jamie"
    fill_in "Last name", with: "Doe"
    fill_in "Username", with: "jamiedoe"
    fill_in "Email address", with: "jamie@example.com"
    fill_in "Password", with: "password1234"
    fill_in "Password confirmation", with: "password1234"

    click_on "Create account"

    assert_text "Welcome to Ruby Gaming"
    assert_text "Hi, Jamie!"
    assert_text "Settings"
    assert_text "Log out"

    click_on "Log out", match: :first

    assert_text "Log in"
    assert_text "Sign up"
    assert_no_text "Log out"
  end
end
