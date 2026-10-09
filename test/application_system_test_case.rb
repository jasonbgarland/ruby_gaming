require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # System tests drive a real browser, so sign in through the real form
  # (integration tests can POST /session directly; a browser can't).
  def sign_in_via_browser(user = users(:one))
    visit new_session_path
    fill_in "Username or email", with: user.email_address
    fill_in "Password", with: "password1234"
    click_on "Sign in"
    assert_text "Log out"
  end
end
