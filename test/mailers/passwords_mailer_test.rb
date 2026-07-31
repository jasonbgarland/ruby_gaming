require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset" do
    user = users(:one)

    perform_enqueued_jobs do
      PasswordsMailer.reset(user).deliver_later
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal "Reset your password", mail.subject
    assert_equal [ user.email_address ], mail.to
    assert_match "password reset page", mail.html_part.body.to_s
    assert_match "/passwords/", mail.html_part.body.to_s
    assert_match "/passwords/", mail.text_part.body.to_s
  end
end
