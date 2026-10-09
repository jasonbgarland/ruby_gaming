require "test_helper"

class GamesShowFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @game = Game.create!(
      igdb_id: 1022, name: "The Legend of Zelda", summary: "An adventure.",
      first_release_date: Date.new(1986, 2, 21), cover_url: "https://example.com/zelda.jpg",
      platforms: [ "NES", "Switch" ], genres: [ "Adventure" ], refreshed_at: Time.current
    )
  end

  test "requires authentication" do
    get game_path(@game.igdb_id)
    assert_redirected_to new_session_path
  end

  test "shows the game's details" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_response :success
    assert_select "h1", "The Legend of Zelda"
    assert_select "img.game-cover[src=?]", "https://example.com/zelda.jpg"
    assert_match "February 21, 1986", response.body
    assert_match "NES, Switch", response.body
    assert_match "Adventure", response.body
    assert_match "An adventure.", response.body
  end

  test "omits sections the game has no data for" do
    @game.update!(summary: nil, first_release_date: nil, cover_url: nil, platforms: [], genres: [])
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_response :success
    assert_select "img.game-cover", count: 0
    assert_no_match "Released", response.body
    assert_no_match "Platforms:", response.body
    assert_no_match "Genres:", response.body
  end

  test "lists only the current user's collections that contain the game" do
    mine = @user.collections.create!(title: "Wishlist")
    mine.collection_games.create!(game: @game, platform: "NES")
    mine.collection_games.create!(game: @game, platform: "Switch")
    @user.collections.create!(title: "Empty")
    users(:two).collections.create!(title: "Graces Secret List")
                .collection_games.create!(game: @game, platform: "NES")
    sign_in(@user)

    get game_path(@game.igdb_id)

    assert_select ".your-stuff li", count: 2
    assert_select ".your-stuff li a[href=?]", collection_path(mine), text: "Wishlist"
    assert_match "(NES)", response.body
    assert_match "(Switch)", response.body
    assert_no_match "Graces Secret List", response.body
    assert_no_match "Empty", response.body
  end

  test "says so when the game is in none of the user's collections" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_match "isn't in any of your collections", response.body
  end

  test "a non-numeric id is a 404" do
    sign_in(@user)
    get game_path("abc")
    assert_response :not_found
  end

  test "an unknown game is a 404 when IGDB does not have it either" do
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(status: 200, body: "[]")
    sign_in(@user)

    get game_path(999_999)
    assert_response :not_found
  end
end
