require "test_helper"

class CollectionGamesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @collection = @user.collections.create!(title: "Wishlist")
    # refreshed_at is current, so Game.find_or_refresh won't call IGDB.
    @game = Game.create!(
      igdb_id: 1022, name: "The Legend of Zelda",
      platforms: [ "NES", "Switch" ], genres: [ "Adventure" ],
      refreshed_at: Time.current
    )

    # Following a redirect to show?q=zelda runs a real IGDB search; stub it.
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "test-token", expires_in: 5_184_000 }.to_json
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(status: 200, body: [].to_json)
  end

  def add_game(collection: @collection, **params)
    post collection_collection_games_path(collection),
         params: { igdb_id: @game.igdb_id, platform: "NES", q: "zelda" }.merge(params)
  end

  test "create requires authentication" do
    add_game

    assert_redirected_to new_session_path
    assert_equal 0, CollectionGame.count
  end

  test "create adds the game on the chosen platform and keeps the search" do
    sign_in(@user)

    assert_difference -> { @collection.collection_games.count }, 1 do
      add_game
    end

    assert_redirected_to collection_path(@collection, q: "zelda")
    follow_redirect!
    assert_match "Added The Legend of Zelda (NES) to Wishlist.", response.body
    assert_equal "NES", @collection.collection_games.last.platform
  end

  test "create allows the same game on a different platform" do
    sign_in(@user)
    add_game(platform: "NES")

    assert_difference -> { @collection.collection_games.count }, 1 do
      add_game(platform: "Switch")
    end
  end

  test "create rejects a duplicate game and platform" do
    sign_in(@user)
    add_game

    assert_no_difference -> { CollectionGame.count } do
      add_game
    end

    follow_redirect!
    assert_select ".flash-alert", /Game has already been added on that platform/
  end

  test "create rejects a platform the game is not on" do
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      add_game(platform: "Xbox")
    end

    follow_redirect!
    assert_select ".flash-alert", /not available for The Legend of Zelda/
  end

  test "create rejects a non-numeric igdb_id" do
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      add_game(igdb_id: "abc")
    end

    follow_redirect!
    assert_select ".flash-alert", "Invalid game."
  end

  test "destroy requires authentication" do
    entry = @collection.collection_games.create!(game: @game, platform: "NES")

    delete collection_collection_game_path(@collection, entry)

    assert_redirected_to new_session_path
    assert CollectionGame.exists?(entry.id)
  end

  test "destroy removes only that platform's entry" do
    nes = @collection.collection_games.create!(game: @game, platform: "NES")
    switch = @collection.collection_games.create!(game: @game, platform: "Switch")
    sign_in(@user)

    assert_difference -> { CollectionGame.count }, -1 do
      delete collection_collection_game_path(@collection, nes)
    end

    assert_redirected_to collection_path(@collection)
    assert_not CollectionGame.exists?(nes.id)
    assert CollectionGame.exists?(switch.id)
    follow_redirect!
    assert_match "Removed The Legend of Zelda (NES).", response.body
  end

  test "destroy 404s on another user's collection" do
    other_collection = @other_user.collections.create!(title: "Graces")
    entry = other_collection.collection_games.create!(game: @game, platform: "NES")
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      delete collection_collection_game_path(other_collection, entry)
    end

    assert_response :not_found
  end

  test "destroy 404s on an entry from a different collection" do
    mine = @collection.collection_games.create!(game: @game, platform: "NES")
    other_collection = @user.collections.create!(title: "Owned")
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      delete collection_collection_game_path(other_collection, mine)
    end

    assert_response :not_found
  end

  test "create reports a game IGDB doesn't know" do
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      add_game(igdb_id: "999999")
    end

    follow_redirect!
    assert_select ".flash-alert", "Couldn't find that game on IGDB."
  end

  test "create 404s on another user's collection" do
    other_collection = @other_user.collections.create!(title: "Graces")
    sign_in(@user)

    assert_no_difference -> { CollectionGame.count } do
      add_game(collection: other_collection)
    end

    assert_response :not_found
  end
end
