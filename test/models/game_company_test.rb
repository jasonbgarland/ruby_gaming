require "test_helper"

class GameCompanyTest < ActiveSupport::TestCase
  setup do
    @game = Game.create!(igdb_id: 1, name: "Elden Ring", refreshed_at: Time.current)
    @company = Company.create!(name: "FromSoftware")
  end

  test "is valid with a developer or publisher role" do
    GameCompany::ROLES.each do |role|
      assert GameCompany.new(game: @game, company: @company, role: role).valid?, role
    end
  end

  test "rejects an unknown role" do
    entry = GameCompany.new(game: @game, company: @company, role: "porter")

    assert_not entry.valid?
    assert_includes entry.errors[:role], "is not included in the list"
  end

  test "a company can be both developer and publisher of one game" do
    GameCompany.create!(game: @game, company: @company, role: "developer")

    assert GameCompany.new(game: @game, company: @company, role: "publisher").valid?
  end

  test "rejects the same company twice in one role on a game" do
    GameCompany.create!(game: @game, company: @company, role: "developer")
    dup = GameCompany.new(game: @game, company: @company, role: "developer")

    assert_not dup.valid?
    assert_includes dup.errors[:company_id], "has already been taken"
  end
end
