require "test_helper"

class CollectionTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "requires a title" do
    collection = Collection.new(user: @user, description: "stuff")
    assert_not collection.valid?
    assert_includes collection.errors[:title], "can't be blank"
  end

  test "title is unique per user" do
    Collection.create!(user: @user, title: "Wishlist")
    dup = Collection.new(user: @user, title: "Wishlist")

    assert_not dup.valid?
    assert_includes dup.errors[:title], "has already been taken"
  end

  test "different users can each have a collection with the same title" do
    other_user = users(:two)
    Collection.create!(user: @user, title: "Wishlist")
    same_title_other_user = Collection.new(user: other_user, title: "Wishlist")

    assert same_title_other_user.valid?
  end

  test "description is optional" do
    collection = Collection.new(user: @user, title: "Wishlist")
    assert collection.valid?
  end

  test "destroying a collection destroys its collection_games" do
    collection = Collection.create!(user: @user, title: "Wishlist")
    game = Game.create!(igdb_id: 1, name: "Test", platforms: [ "PC" ], refreshed_at: Time.current)
    collection.collection_games.create!(game: game, platform: "PC")

    assert_difference("CollectionGame.count", -1) { collection.destroy }
  end

  test "games returns the games added through collection_games" do
    collection = Collection.create!(user: @user, title: "Wishlist")
    game = Game.create!(igdb_id: 1, name: "Test", platforms: [ "PC" ], refreshed_at: Time.current)
    collection.collection_games.create!(game: game, platform: "PC")

    assert_equal [ game ], collection.games
  end
end
