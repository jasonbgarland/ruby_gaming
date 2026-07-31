require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      first_name: "Alice",
      last_name: "Smith",
      username: "alice_smith-1",
      email_address: "alice@example.com",
      password: "password1234",
      password_confirmation: "password1234"
    }.merge(overrides)
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "valid user saves" do
    user = User.new(valid_attributes)
    assert user.save
  end

  test "requires first_name" do
    user = User.new(valid_attributes(first_name: ""))
    assert_not user.valid?
    assert_includes user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    user = User.new(valid_attributes(last_name: ""))
    assert_not user.valid?
    assert_includes user.errors[:last_name], "can't be blank"
  end

  test "requires username" do
    user = User.new(valid_attributes(username: ""))
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "rejects username longer than 20 characters" do
    user = User.new(valid_attributes(username: "a" * 21))
    assert_not user.valid?
    assert_includes user.errors[:username], "is too long (maximum is 20 characters)"
  end

  test "rejects username with disallowed characters" do
    user = User.new(valid_attributes(username: "bad*name!"))
    assert_not user.valid?
    assert_not_empty user.errors[:username]
  end

  test "rejects unicode usernames" do
    user = User.new(valid_attributes(username: "üser"))
    assert_not user.valid?
    assert_not_empty user.errors[:username]
  end

  test "rejects duplicate username case-insensitively" do
    existing = User.create!(valid_attributes)
    dup = User.new(valid_attributes(username: existing.username.upcase, email_address: "someoneelse@example.com"))
    assert_not dup.valid?
    assert_includes dup.errors[:username], "has already been taken"
  end

  test "rejects invalid email format" do
    user = User.new(valid_attributes(email_address: "not-an-email"))
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "rejects duplicate email case-insensitively" do
    existing = User.create!(valid_attributes)
    dup = User.new(valid_attributes(email_address: existing.email_address.upcase, username: "someoneelse"))
    assert_not dup.valid?
    assert_includes dup.errors[:email_address], "has already been taken"
  end

  test "rejects short password" do
    user = User.new(valid_attributes(password: "short", password_confirmation: "short"))
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "rejects mismatched password confirmation" do
    user = User.new(valid_attributes(password_confirmation: "different1234"))
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "authenticate works with correct password" do
    user = User.create!(valid_attributes)
    assert_equal user, user.authenticate("password1234")
  end

  test "authenticate fails with wrong password" do
    user = User.create!(valid_attributes)
    assert_not user.authenticate("wrongpassword")
  end

  test "password_reset_token is generatable" do
    user = User.create!(valid_attributes)
    assert user.password_reset_token.present?
    assert_equal user, User.find_by_password_reset_token!(user.password_reset_token)
  end

  test "no plaintext password column exists" do
    columns = User.column_names
    assert_includes columns, "password_digest"
    assert_not_includes columns, "password"
  end
end
