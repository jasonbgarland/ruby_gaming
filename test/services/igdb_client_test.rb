require "test_helper"

class IgdbClientTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  TOKEN_URL = "https://id.twitch.tv/oauth2/token"
  GAMES_URL = "https://api.igdb.com/v4/games"

  def build_client(cache: ActiveSupport::Cache::MemoryStore.new, client_id: "test-client-id", client_secret: "test-client-secret")
    IgdbClient.new(client_id: client_id, client_secret: client_secret, cache: cache)
  end

  def stub_token(expires_in: 5_184_000, status: 200, body: nil)
    payload = body || { access_token: "test-token-#{SecureRandom.hex(4)}", expires_in: expires_in }.to_json
    stub_request(:post, TOKEN_URL).to_return(status: status, body: payload)
  end

  def stub_games(body:, status: 200)
    stub_request(:post, GAMES_URL).to_return(status: status, body: body)
  end

  def full_row
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

  def sparse_row
    { "id" => 42, "name" => "Sparse Game" }
  end

  # 3 - fetches a token on first search
  test "fetches a token on first search" do
    token_stub = stub_token
    stub_games(body: "[]")

    build_client.search("zelda")

    assert_requested(token_stub, times: 1)
    assert_requested(:post, TOKEN_URL, body: hash_including("grant_type" => "client_credentials"))
  end

  # 4 - reuses the cached token across searches
  test "reuses the cached token across searches" do
    token_stub = stub_token
    stub_games(body: "[]")
    client = build_client

    client.search("zelda")
    client.search("link")

    assert_requested(token_stub, times: 1)
  end

  # 5 - shares the cached token across client instances
  test "shares the cached token across client instances" do
    token_stub = stub_token
    stub_games(body: "[]")
    shared_cache = ActiveSupport::Cache::MemoryStore.new

    build_client(cache: shared_cache).search("zelda")
    build_client(cache: shared_cache).search("link")

    assert_requested(token_stub, times: 1)
  end

  # 6 - refetches the token after it expires
  test "refetches the token after it expires" do
    token_stub = stub_token(expires_in: 3600)
    stub_games(body: "[]")
    client = build_client

    client.search("zelda")
    travel (3600 - IgdbClient::TOKEN_EXPIRY_MARGIN + 1).seconds
    client.search("zelda")

    assert_requested(token_stub, times: 2)
  ensure
    travel_back
  end

  # 7 - raises AuthenticationError when Twitch rejects the credentials
  test "raises AuthenticationError when Twitch rejects the credentials" do
    stub_token(status: 403, body: { message: "invalid client" }.to_json)

    error = assert_raises(IgdbClient::AuthenticationError) do
      build_client.search("zelda")
    end

    refute_includes error.message, "test-client-secret"
  end

  # 8 - retries once with a fresh token after an IGDB 401
  test "retries once with a fresh token after an IGDB 401" do
    stub_token
    stub_request(:post, GAMES_URL)
      .to_return(status: 401, body: "unauthorized")
      .then
      .to_return(status: 200, body: "[]")

    result = build_client.search("zelda")

    assert_equal [], result
    assert_requested(:post, TOKEN_URL, times: 2)
  end

  # 9 - raises AuthenticationError when IGDB keeps returning 401
  test "raises AuthenticationError when IGDB keeps returning 401" do
    stub_token
    games_stub = stub_request(:post, GAMES_URL).to_return(status: 401, body: "unauthorized")

    assert_raises(IgdbClient::AuthenticationError) do
      build_client.search("zelda")
    end

    assert_requested(games_stub, times: 2)
  end

  # 10 - sends Client-ID and bearer token headers
  test "sends Client-ID and bearer token headers" do
    stub_token(body: { access_token: "abc-token", expires_in: 5_184_000 }.to_json)
    stub_games(body: "[]")

    build_client.search("zelda")

    assert_requested(:post, GAMES_URL) do |req|
      req.headers["Client-Id"] == "test-client-id" &&
        req.headers["Authorization"] == "Bearer abc-token"
    end
  end

  # 11 - builds an Apicalypse query body
  test "builds an Apicalypse query body" do
    stub_token
    stub_games(body: "[]")

    build_client.search("zelda")

    assert_requested(:post, GAMES_URL) do |req|
      req.body.include?("fields id,name,summary,first_release_date,cover.image_id,platforms.name,genres.name;") &&
        req.body.include?('search "zelda";') &&
        req.body.include?("limit 20;")
    end
  end

  # 12 - escapes quotes and backslashes in the query
  test "escapes quotes and backslashes in the query" do
    stub_token
    stub_games(body: "[]")

    build_client.search(%q(say "hi"\\))

    assert_requested(:post, GAMES_URL) do |req|
      req.body.include?('search "say \"hi\"\\\\";')
    end
  end

  # 13 - honors an explicit limit
  test "honors an explicit limit" do
    stub_token
    stub_games(body: "[]")

    build_client.search("zelda", limit: 5)

    assert_requested(:post, GAMES_URL) do |req|
      req.body.include?("limit 5;")
    end
  end

  # 14 - normalizes a complete IGDB row
  test "normalizes a complete IGDB row" do
    stub_token
    stub_games(body: [ full_row ].to_json)

    games = build_client.search("zelda")

    assert_equal 1, games.size
    game = games.first
    assert_equal 1022, game.igdb_id
    assert_equal "The Legend of Zelda", game.name
    assert_equal "abc123", game.cover_image_id
    assert_equal "https://images.igdb.com/igdb/image/upload/t_cover_big/abc123.jpg", game.cover_url
    assert_equal "An adventure.", game.summary
    assert_equal Time.at(486_432_000).utc.to_date, game.release_date
    assert_equal [ "NES", "Switch" ], game.platforms
    assert_equal [ "Adventure" ], game.genres
  end

  # 15 - normalizes a sparse IGDB row
  test "normalizes a sparse IGDB row" do
    stub_token
    stub_games(body: [ sparse_row ].to_json)

    game = build_client.search("sparse").first

    assert_equal 42, game.igdb_id
    assert_equal "Sparse Game", game.name
    assert_nil game.summary
    assert_nil game.cover_image_id
    assert_nil game.cover_url
    assert_nil game.release_date
    assert_equal [], game.platforms
    assert_equal [], game.genres
  end

  # 16 - returns an empty array for no results
  test "returns an empty array for no results" do
    stub_token
    stub_games(body: "[]")

    assert_equal [], build_client.search("zzzz")
  end

  # 17 - raises ResponseError on malformed JSON
  test "raises ResponseError on malformed JSON" do
    stub_token
    stub_games(body: "not json")

    assert_raises(IgdbClient::ResponseError) do
      build_client.search("zelda")
    end
  end

  # 18 - raises ResponseError when the body is not an array
  test "raises ResponseError when the body is not an array" do
    stub_token
    stub_games(body: { message: "nope" }.to_json)

    assert_raises(IgdbClient::ResponseError) do
      build_client.search("zelda")
    end
  end

  # 19 - skips rows without an id
  test "skips rows without an id" do
    stub_token
    stub_games(body: [ { "id" => 1, "name" => "A" }, { "name" => "no id" }, "garbage" ].to_json)

    games = build_client.search("zelda")

    assert_equal 1, games.size
    assert_equal 1, games.first.igdb_id
  end

  # 20 - raises RequestError on an IGDB server error
  test "raises RequestError on an IGDB server error" do
    stub_token
    stub_games(body: "internal error", status: 500)

    error = assert_raises(IgdbClient::RequestError) do
      build_client.search("zelda")
    end

    assert_includes error.message, "500"
  end

  # 21 - raises ConfigurationError without credentials
  test "raises ConfigurationError without credentials" do
    assert_raises(IgdbClient::ConfigurationError) do
      IgdbClient.new(client_id: nil, client_secret: nil, cache: ActiveSupport::Cache::MemoryStore.new)
    end
  end

  # 22 - returns empty without any HTTP for a blank query
  test "returns empty without any HTTP for a blank query" do
    token_stub = stub_token
    games_stub = stub_games(body: "[]")

    result = build_client.search("   ")

    assert_equal [], result
    assert_not_requested(token_stub)
    assert_not_requested(games_stub)
  end

  # 23 - find builds a where-id Apicalypse query
  test "find builds a where-id Apicalypse query" do
    stub_token
    stub_games(body: [ full_row ].to_json)

    build_client.find(1022)

    assert_requested(:post, GAMES_URL) do |req|
      req.body.include?("fields id,name,summary,first_release_date,cover.image_id,platforms.name,genres.name;") &&
        req.body.include?("where id = 1022;") &&
        !req.body.include?("search")
    end
  end

  # 24 - find returns a normalized game
  test "find returns a normalized game" do
    stub_token
    stub_games(body: [ full_row ].to_json)

    game = build_client.find(1022)

    assert_equal 1022, game.igdb_id
    assert_equal "The Legend of Zelda", game.name
  end

  # 25 - find returns nil when IGDB has no matching game
  test "find returns nil when IGDB has no matching game" do
    stub_token
    stub_games(body: "[]")

    assert_nil build_client.find(999_999)
  end

  # 26 - find returns nil without any HTTP for a blank id
  test "find returns nil without any HTTP for a blank id" do
    token_stub = stub_token
    games_stub = stub_games(body: "[]")

    assert_nil build_client.find(nil)
    assert_not_requested(token_stub)
    assert_not_requested(games_stub)
  end
end
