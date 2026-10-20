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

  test "shows the IGDB detail fields and an attribution link" do
    @game.update!(
      game_type: "Main Game", game_modes: [ "Single player", "Co-operative" ],
      themes: [ "Fantasy", "Action" ], age_ratings: [ "ESRB E10+", "PEGI 7" ],
      igdb_url: "https://www.igdb.com/games/the-legend-of-zelda"
    )
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_match "Main Game", response.body
    assert_match "Single player, Co-operative", response.body
    assert_match "Fantasy, Action", response.body
    assert_match "ESRB E10+, PEGI 7", response.body
    assert_select "p.attribution a[href=?]", "https://www.igdb.com/games/the-legend-of-zelda", text: "IGDB"
  end

  test "shows the developer and publisher" do
    nintendo = Company.create!(name: "Nintendo")
    capcom = Company.create!(name: "Capcom")
    @game.game_companies.create!(company: nintendo, role: "developer")
    @game.game_companies.create!(company: nintendo, role: "publisher")
    @game.game_companies.create!(company: capcom, role: "publisher")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_match "Developer:</strong> Nintendo</p>", response.body
    assert_match "Publisher:</strong> Capcom, Nintendo</p>", response.body
  end

  test "attributes IGDB as plain text when the game has no IGDB url yet" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select "p.attribution", text: /sourced from IGDB/
    assert_select "p.attribution a", count: 0
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
    assert_no_match "Developer:", response.body
    assert_no_match "Publisher:", response.body
    assert_no_match "Type:", response.body
    assert_no_match "Game modes:", response.body
    assert_no_match "Themes:", response.body
    assert_no_match "Age ratings:", response.body
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
    assert_select ".your-stuff li", text: /Empty/, count: 0
  end

  test "offers a form to add the game to one of the user's collections" do
    mine = @user.collections.create!(title: "Wishlist")
    users(:two).collections.create!(title: "Graces Secret List")
    sign_in(@user)

    get game_path(@game.igdb_id)

    assert_select "form[action=?]", collection_games_path do
      assert_select "input[name=igdb_id][value=?]", "1022"
      assert_select "input[name=from][value=game]"
      assert_select "select[name=collection_id] option", count: 1
      assert_select "select[name=collection_id] option[value=?]", mine.id.to_s
      assert_select "select[name=platform] option", count: 2
    end
  end

  test "each collection entry has a Remove button that returns to the game page" do
    mine = @user.collections.create!(title: "Wishlist")
    entry = mine.collection_games.create!(game: @game, platform: "NES")
    sign_in(@user)

    get game_path(@game.igdb_id)

    assert_select "form[action=?] input[name=from][value=game]", collection_collection_game_path(mine, entry)
  end

  test "points to creating a collection when the user has none" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select "form[action=?]", collection_games_path, count: 0
    assert_select "a[href=?]", new_collection_path, text: "Create one"
  end

  test "says so when the game is in none of the user's collections" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_match "isn't in any of your collections", response.body
  end

  test "fetches an uncached game from IGDB, saves its detail fields and shows them" do
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(
      status: 200,
      body: [ {
        "id" => 119_133, "name" => "Elden Ring", "summary" => "A big world.",
        "url" => "https://www.igdb.com/games/elden-ring", "slug" => "elden-ring",
        "game_type" => { "type" => "Main Game" },
        "game_modes" => [ { "name" => "Single player" }, { "name" => "Multiplayer" } ],
        "themes" => [ { "name" => "Fantasy" }, { "name" => "Open world" } ],
        "involved_companies" => [
          { "developer" => true, "publisher" => false, "company" => { "name" => "FromSoftware" } },
          { "developer" => false, "publisher" => true, "company" => { "name" => "Bandai Namco" } }
        ],
        "age_ratings" => [
          { "organization" => { "name" => "ESRB" }, "rating_category" => { "rating" => "M" } },
          { "organization" => { "name" => "CERO" }, "rating_category" => { "rating" => "D" } }
        ]
      } ].to_json
    )
    sign_in(@user)
    assert_not Game.exists?(igdb_id: 119_133)

    get game_path(119_133)

    assert_response :success
    assert_requested(:post, "https://api.igdb.com/v4/games", times: 1)
    saved = Game.find_by!(igdb_id: 119_133)
    assert_equal "Main Game", saved.game_type
    assert_equal [ "Single player", "Multiplayer" ], saved.game_modes
    assert_equal [ "ESRB M" ], saved.age_ratings
    assert_select "h1", "Elden Ring"
    assert_match "Single player, Multiplayer", response.body
    assert_match "Fantasy, Open world", response.body
    assert_equal [ [ "Bandai Namco", "publisher" ], [ "FromSoftware", "developer" ] ],
      saved.game_companies.includes(:company).map { |gc| [ gc.company.name, gc.role ] }.sort
    assert_match "Developer:</strong> FromSoftware</p>", response.body
    assert_match "Publisher:</strong> Bandai Namco</p>", response.body
    assert_match "ESRB M", response.body
    assert_no_match "CERO", response.body
    assert_select "p.attribution a[href=?]", "https://www.igdb.com/games/elden-ring"
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
