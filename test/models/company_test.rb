require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "requires a name" do
    company = Company.new
    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "name is unique ignoring case" do
    Company.create!(name: "Nintendo")
    dup = Company.new(name: "nintendo")

    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end
end
