require "test_helper"

class CollectionGameTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  TOKEN_URL = "https://id.twitch.tv/oauth2/token"
  GAMES_URL = "https://api.igdb.com/v4/games"

  setup do
    @user = users(:one)
    @collection = Collection.create!(user: @user, title: "Wishlist")
    @game = Game.create!(
      igdb_id: 1022,
      name: "The Legend of Zelda",
      platforms: [ "NES", "Switch" ],
      refreshed_at: Time.current
    )
  end

  def stub_token
    stub_request(:post, TOKEN_URL).to_return(
      status: 200,
      body: { access_token: "test-token", expires_in: 5_184_000 }.to_json
    )
  end

  def stub_games(body:)
    stub_request(:post, GAMES_URL).to_return(status: 200, body: body)
  end

  test "requires a platform" do
    collection_game = CollectionGame.new(collection: @collection, game: @game)
    assert_not collection_game.valid?
    assert_includes collection_game.errors[:platform], "can't be blank"
  end

  test "platform must be one the game actually has" do
    collection_game = CollectionGame.new(collection: @collection, game: @game, platform: "PC")
    assert_not collection_game.valid?
    assert_includes collection_game.errors[:platform], "is not available for The Legend of Zelda"
  end

  test "valid when platform is one of the game's platforms" do
    collection_game = CollectionGame.new(collection: @collection, game: @game, platform: "Switch")
    assert collection_game.valid?
  end

  test "same game can appear twice in a collection at different platforms" do
    @collection.collection_games.create!(game: @game, platform: "NES")
    second = CollectionGame.new(collection: @collection, game: @game, platform: "Switch")

    assert second.valid?
  end

  test "same game at the same platform can't be added twice to a collection" do
    @collection.collection_games.create!(game: @game, platform: "NES")
    dup = CollectionGame.new(collection: @collection, game: @game, platform: "NES")

    assert_not dup.valid?
    assert_includes dup.errors[:game_id], "has already been taken"
  end

  test "refreshes a stale game from IGDB before validating the platform" do
    @game.update!(refreshed_at: (Game::REFRESH_INTERVAL + 1.hour).ago)
    stub_token
    stub_games(body: [ {
      "id" => 1022,
      "name" => "The Legend of Zelda",
      "platforms" => [ { "name" => "NES" }, { "name" => "Switch" }, { "name" => "PC" } ]
    } ].to_json)

    collection_game = CollectionGame.new(collection: @collection, game: @game, platform: "PC")

    assert collection_game.valid?
    assert_equal [ "NES", "Switch", "PC" ], @game.reload.platforms
  end
end
