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

  test "new and create require authentication" do
    get new_collection_path
    assert_redirected_to new_session_path

    post collections_path, params: { collection: { title: "Wishlist" } }
    assert_redirected_to new_session_path
    assert_equal 0, Collection.count
  end

  test "new renders the form" do
    sign_in(@user)
    get new_collection_path

    assert_response :success
    assert_select "form[action=?]", collections_path
    assert_select "input[name=?]", "collection[title]"
    assert_select "textarea[name=?]", "collection[description]"
  end

  test "create saves a collection for the current user and redirects to it" do
    sign_in(@user)

    assert_difference -> { @user.collections.count }, 1 do
      post collections_path, params: { collection: { title: "Wishlist", description: "Games I want" } }
    end

    collection = @user.collections.find_by!(title: "Wishlist")
    assert_equal "Games I want", collection.description
    assert_redirected_to collection_path(collection)

    follow_redirect!
    assert_match "Collection created.", response.body
  end

  test "create with a blank title re-renders the form with errors" do
    sign_in(@user)

    assert_no_difference "Collection.count" do
      post collections_path, params: { collection: { title: "" } }
    end

    assert_response :unprocessable_entity
    assert_match "Title", response.body
  end

  test "create rejects a duplicate title for the same user" do
    @user.collections.create!(title: "Wishlist")
    sign_in(@user)

    assert_no_difference "Collection.count" do
      post collections_path, params: { collection: { title: "Wishlist" } }
    end

    assert_response :unprocessable_entity
  end

  test "create allows the same title as another user's collection" do
    @other_user.collections.create!(title: "Wishlist")
    sign_in(@user)

    assert_difference -> { @user.collections.count }, 1 do
      post collections_path, params: { collection: { title: "Wishlist" } }
    end
  end

  test "create ignores a user_id param and always uses the current user" do
    sign_in(@user)

    post collections_path, params: { collection: { title: "Sneaky", user_id: @other_user.id } }

    assert_equal [ "Sneaky" ], @user.collections.pluck(:title)
    assert_equal 0, @other_user.collections.count
  end

  test "edit and update require authentication" do
    collection = @user.collections.create!(title: "Wishlist")

    get edit_collection_path(collection)
    assert_redirected_to new_session_path

    patch collection_path(collection), params: { collection: { title: "Changed" } }
    assert_redirected_to new_session_path
    assert_equal "Wishlist", collection.reload.title
  end

  test "edit renders the form prefilled with the collection's values" do
    collection = @user.collections.create!(title: "Wishlist", description: "Games I want")

    sign_in(@user)
    get edit_collection_path(collection)

    assert_response :success
    assert_select "form[action=?]", collection_path(collection)
    assert_select "input[name=?][value=?]", "collection[title]", "Wishlist"
    assert_select "textarea[name=?]", "collection[description]", text: "Games I want"
  end

  test "update changes the collection and redirects to it" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    patch collection_path(collection), params: { collection: { title: "Backlog", description: "To play" } }

    assert_redirected_to collection_path(collection)
    collection.reload
    assert_equal "Backlog", collection.title
    assert_equal "To play", collection.description

    follow_redirect!
    assert_match "Collection updated.", response.body
  end

  test "update with a blank title re-renders the form with errors" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    patch collection_path(collection), params: { collection: { title: "" } }

    assert_response :unprocessable_entity
    assert_match "Title", response.body
    assert_equal "Wishlist", collection.reload.title
  end

  test "update rejects a title that duplicates another of the user's collections" do
    @user.collections.create!(title: "Owned")
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    patch collection_path(collection), params: { collection: { title: "Owned" } }

    assert_response :unprocessable_entity
    assert_equal "Wishlist", collection.reload.title
  end

  test "update cannot reassign a collection to another user" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    patch collection_path(collection), params: { collection: { user_id: @other_user.id } }

    assert_equal @user, collection.reload.user
  end

  test "edit and update return 404 for another user's collection" do
    other_collection = @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    get edit_collection_path(other_collection)
    assert_response :not_found

    patch collection_path(other_collection), params: { collection: { title: "Hijacked" } }
    assert_response :not_found
    assert_equal "Graces Secret List", other_collection.reload.title
  end

  test "destroy requires authentication" do
    collection = @user.collections.create!(title: "Wishlist")

    assert_no_difference "Collection.count" do
      delete collection_path(collection)
    end
    assert_redirected_to new_session_path
  end

  test "destroy deletes the collection and redirects to the index with a notice" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    assert_difference -> { @user.collections.count }, -1 do
      delete collection_path(collection)
    end

    assert_redirected_to collections_path
    assert_response :see_other

    follow_redirect!
    assert_match "Collection deleted.", response.body
  end

  test "destroy removes the collection's games entries but keeps the cached Game" do
    collection = @user.collections.create!(title: "Wishlist")
    game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda",
                        platforms: [ "NES", "Switch" ], refreshed_at: Time.current)
    collection.collection_games.create!(game: game, platform: "Switch")

    sign_in(@user)
    assert_difference "CollectionGame.count", -1 do
      assert_no_difference "Game.count" do
        delete collection_path(collection)
      end
    end
  end

  test "destroy returns 404 for another user's collection and deletes nothing" do
    other_collection = @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    assert_no_difference "Collection.count" do
      delete collection_path(other_collection)
    end

    assert_response :not_found
  end

  test "show page has a delete button" do
    collection = @user.collections.create!(title: "Wishlist")

    sign_in(@user)
    get collection_path(collection)

    assert_select "form[action=?]", collection_path(collection) do
      assert_select "input[name=_method][value=delete]"
    end
  end

  test "show returns 404 for another user's collection" do
    other_collection = @other_user.collections.create!(title: "Graces Secret List")

    sign_in(@user)
    get collection_path(other_collection)

    assert_response :not_found
  end
end
