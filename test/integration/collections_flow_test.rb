require "test_helper"

class CollectionsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
  end

  test "index requires authentication" do
    get collections_path
    assert_redirected_to new_session_path
  end

  test "index shows an empty state when the user has no collections" do
    sign_in(@user)
    get collections_path

    assert_response :success
    assert_match "any collections yet", response.body
  end

  test "index lists only the current user's collections, ordered by title" do
    @user.collections.create!(title: "Wishlist", description: "Games I want")
    @user.collections.create!(title: "Owned")
    @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    get collections_path

    assert_response :success
    assert_match "Games I want", response.body
    assert_no_match "Graces Secret List", response.body
    assert_operator response.body.index("Owned"), :<, response.body.index("Wishlist")
  end

  test "show requires authentication" do
    collection = @user.collections.create!(title: "Wishlist")

    get collection_path(collection)
    assert_redirected_to new_session_path
  end

  test "show displays the collection's games with their platforms" do
    collection = @user.collections.create!(title: "Wishlist", description: "Games I want")
    game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda",
                        platforms: [ "NES", "Switch" ], refreshed_at: Time.current)
    collection.collection_games.create!(game: game, platform: "Switch")

    sign_in(@user)
    get collection_path(collection)

    assert_response :success
    assert_match "Wishlist", response.body
    assert_match "Games I want", response.body
    assert_match "The Legend of Zelda", response.body
    assert_match "Switch", response.body
  end

  test "show displays an empty state for a collection with no games" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    get collection_path(collection)

    assert_response :success
    assert_match "No games in this collection yet", response.body
  end

  test "show returns 404 for another user's collection" do
    other_collection = @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    get collection_path(other_collection)

    assert_response :not_found
  end
end
