require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  def seed
    capture_io { Rails.application.load_seed }
  end

  test "seeds the games, the demo user and its collections without calling IGDB" do
    # WebMock blocks all non-local HTTP, so any IGDB call would fail this test.
    seed

    assert_equal 100, Game.count
    assert Company.count.positive?
    assert User.find_by!(email_address: "demo@example.com").authenticate("demo-password-123")

    collections = User.find_by!(email_address: "demo@example.com").collections.order(:title)
    assert_equal [ "All-time favourites", "Currently playing", "Wishlist" ], collections.map(&:title)
    assert_equal [ 8, 4, 5 ], collections.map { |c| c.collection_games.count }
  end

  test "is idempotent" do
    seed
    counts = [ Game, Company, GameCompany, User, Collection, CollectionGame ].map(&:count)

    seed

    assert_equal counts, [ Game, Company, GameCompany, User, Collection, CollectionGame ].map(&:count)
  end

  test "restores the demo password if it was changed" do
    seed
    User.find_by!(email_address: "demo@example.com").update!(password: "something-else-1")

    seed

    assert User.find_by!(email_address: "demo@example.com").authenticate("demo-password-123")
  end

  test "seeded games are fresh, so viewing them needs no IGDB refresh" do
    seed

    assert Game.all.none?(&:stale?)
  end

  test "refuses to run in production" do
    original = Rails.env
    Rails.env = "production"

    assert_raises(SystemExit) { capture_io { Rails.application.load_seed } }
    assert_equal 0, Game.count
  ensure
    Rails.env = original
  end
end
