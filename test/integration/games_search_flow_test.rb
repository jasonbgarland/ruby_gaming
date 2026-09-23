require "test_helper"

class GamesSearchFlowTest < ActionDispatch::IntegrationTest
  TOKEN_URL = "https://id.twitch.tv/oauth2/token"
  GAMES_URL = "https://api.igdb.com/v4/games"

  setup { @user = users(:one) }

  def stub_token
    stub_request(:post, TOKEN_URL).to_return(
      status: 200,
      body: { access_token: "test-token", expires_in: 5_184_000 }.to_json
    )
  end

  def stub_games(body:)
    stub_request(:post, GAMES_URL).to_return(status: 200, body: body)
  end

  def zelda_row
    {
      "id" => 1022,
      "name" => "The Legend of Zelda",
      "summary" => "An adventure.",
      "first_release_date" => 486_432_000,
      "cover" => { "image_id" => "abc123" },
      "platforms" => [ { "name" => "NES" }, { "name" => "Switch" } ],
      "genres" => [ { "name" => "Adventure" } ]
    }
  end

  test "requires authentication" do
    get games_search_path
    assert_redirected_to new_session_path
  end

  test "blank query shows the search form without hitting IGDB" do
    sign_in(@user)
    get games_search_path
    assert_response :success
    assert_match "Search games", response.body
  end

  test "searching renders live IGDB results" do
    sign_in(@user)
    stub_token
    stub_games(body: [ zelda_row ].to_json)

    get games_search_path, params: { q: "zelda" }

    assert_response :success
    assert_match "The Legend of Zelda", response.body
    assert_match "NES, Switch", response.body
  end

  test "searching with no matches shows an empty state" do
    sign_in(@user)
    stub_token
    stub_games(body: "[]")

    get games_search_path, params: { q: "nonexistent-game-xyz" }

    assert_response :success
    assert_match "No results", response.body
  end

  test "selecting a result upserts a local Game row" do
    sign_in(@user)
    stub_token
    stub_games(body: [ zelda_row ].to_json)

    assert_difference "Game.count", 1 do
      post games_path, params: { igdb_id: 1022, q: "zelda" }
    end

    assert_redirected_to games_search_path(q: "zelda")
    game = Game.find_by(igdb_id: 1022)
    assert_equal "The Legend of Zelda", game.name
    assert_equal [ "NES", "Switch" ], game.platforms
  end

  test "selecting the same result twice updates rather than duplicates" do
    sign_in(@user)
    stub_token
    stub_games(body: [ zelda_row ].to_json)

    post games_path, params: { igdb_id: 1022, q: "zelda" }

    assert_no_difference "Game.count" do
      post games_path, params: { igdb_id: 1022, q: "zelda" }
    end
  end

  test "selecting an igdb_id IGDB doesn't recognize shows an alert without creating a row" do
    sign_in(@user)
    stub_token
    stub_games(body: "[]")

    assert_no_difference "Game.count" do
      post games_path, params: { igdb_id: 999_999, q: "zelda" }
    end

    assert_redirected_to games_search_path(q: "zelda")
    follow_redirect!
    assert_match "Couldn&#39;t find that game", response.body
  end

  test "rejects a non-numeric igdb_id without hitting IGDB" do
    sign_in(@user)

    assert_no_difference "Game.count" do
      post games_path, params: { igdb_id: "not-a-number", q: "zelda" }
    end

    assert_redirected_to games_search_path(q: "zelda")
  end
end
