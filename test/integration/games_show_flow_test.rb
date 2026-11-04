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

  # An extra user (beyond the two fixtures), for tests that need many reviewers.
  def reviewer(number)
    User.create!(first_name: "Reviewer", last_name: number.to_s, username: "reviewer#{number}",
                 email_address: "reviewer#{number}@example.com", password: "password1234")
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
    assert_select "dl.facts div", text: "ReleasedFebruary 21, 1986"
    assert_select ".platforms .chip", count: 2
    assert_select ".platforms .chip", text: "NES"
    assert_select ".chip-group .chip", text: "Adventure"
    assert_select "p.summary", text: "An adventure."
  end

  test "flags a game that is not a Main Game with a type badge" do
    @game.update!(game_type: "DLC")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".game-type .badge-type", text: "DLC"
    assert_select "dl.facts dt", text: "Type", count: 0
  end

  test "shows short platform names with the full IGDB name as a tooltip" do
    @game.update!(platforms: [ "PC (Microsoft Windows)", "Xbox Series X|S" ])
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".platforms .chip[title=?]", "PC (Microsoft Windows)", text: "PC"
    assert_select ".platforms .chip", text: "Xbox Series X|S"
  end

  test "shows a short summary in full with no toggle" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".summary details", count: 0
  end

  test "folds a long summary behind a native details toggle" do
    long_summary = "word " * 120
    @game.update!(summary: long_summary)
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".summary-preview", text: /\Aword word.*…\z/
    assert_select ".summary details summary", text: "Read more"
    assert_select ".summary details p", text: long_summary.strip
  end

  test "shows the IGDB detail fields and an attribution link" do
    @game.update!(
      game_type: "Main Game", game_modes: [ "Single player", "Co-operative" ],
      themes: [ "Fantasy", "Action" ], age_ratings: [ "ESRB E10+", "PEGI 7" ],
      igdb_url: "https://www.igdb.com/games/the-legend-of-zelda"
    )
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".game-type", count: 0
    assert_select ".chip-group .chip", text: "Single player"
    assert_select ".chip-group .chip", text: "Co-operative"
    assert_select ".chip-group .chip", text: "Fantasy"
    assert_select ".chip-group .chip", text: "Action"
    assert_select ".chip-group .badge", text: "ESRB E10+"
    assert_select ".chip-group .badge", text: "PEGI 7"
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

    assert_select "dl.facts div", text: "DeveloperNintendo"
    assert_select "dl.facts div", text: "PublisherCapcom, Nintendo"
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
    assert_select ".platforms", count: 0
    assert_select "dl.facts", count: 0
    assert_select ".game-type", count: 0
    assert_select ".chip-group", count: 0
    assert_select ".summary", count: 0
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
    assert_select ".your-stuff li .chip", text: "NES"
    assert_select ".your-stuff li .chip", text: "Switch"
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
    assert_select ".chip-group .chip", text: "Single player"
    assert_select ".chip-group .chip", text: "Multiplayer"
    assert_select ".chip-group .chip", text: "Open world"
    assert_equal [ [ "Bandai Namco", "publisher" ], [ "FromSoftware", "developer" ] ],
      saved.game_companies.includes(:company).map { |gc| [ gc.company.name, gc.role ] }.sort
    assert_select "dl.facts div", text: "DeveloperFromSoftware"
    assert_select "dl.facts div", text: "PublisherBandai Namco"
    assert_select ".chip-group .badge", text: "ESRB M"
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

  test "shows ten half-star radios, none checked, when the user has not rated" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select "form.rating-form[action=?]", game_rating_path(@game.igdb_id)
    assert_select "input[type=radio][name=rating_halves]", count: 10
    assert_select "input[type=radio][name=rating_halves][checked]", count: 0
    assert_select ".rating-summary", text: /haven't rated/
    assert_select ".rating-summary form[action=?]", game_rating_path(@game.igdb_id), count: 0
  end

  test "checks the user's own rating and offers Clear" do
    @user.ratings.create!(game: @game, rating_halves: 9)
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select "input[type=radio][name=rating_halves][checked]", count: 1
    assert_select "input[type=radio][name=rating_halves][value=?][checked]", "9"
    assert_select ".rating-summary", text: /You rated it 4\.5 stars/
    assert_select ".rating-summary form[action=?] button", game_rating_path(@game.igdb_id), text: "Clear"
  end

  test "says so when nobody has rated the game" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".rating-average", text: /No ratings yet/
  end

  test "shows the average and count across all users, not just the viewer's" do
    @user.ratings.create!(game: @game, rating_halves: 9)
    users(:two).ratings.create!(game: @game, rating_halves: 6)
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".rating-average", text: /Average 3\.8 stars from 2 ratings/
  end

  test "another user's rating is not checked for the viewer" do
    users(:two).ratings.create!(game: @game, rating_halves: 6)
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select "input[type=radio][name=rating_halves][checked]", count: 0
  end

  test "says so when the game has no short reviews, and offers to write one" do
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".game-reviews .review-empty", text: "No short reviews yet."
    assert_select ".game-reviews a[href=?]", new_game_review_path(@game.igdb_id), text: "Write your review"
    assert_select ".game-reviews a", text: /See all reviews/, count: 0
  end

  test "shows short reviews from everyone as cards, newest first, and leaves long ones out" do
    @game.reviews.create!(user: @user, kind: "short", body: "Older take.", created_at: 2.days.ago)
    @game.reviews.create!(user: users(:two), kind: "short", title: "Brilliant", body: "Newer take.", created_at: 1.day.ago)
    @game.reviews.create!(user: reviewer(1), kind: "long", title: "A deep dive", body: "Long thoughts.")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_equal [ "Newer take.", "Older take." ], css_select(".review-card .review-body").map(&:text)
    assert_select ".review-card-title", text: "Brilliant"
    assert_select ".review-card .review-meta", text: /grace/
    assert_select ".review-card", text: /Long thoughts/, count: 0
  end

  test "links to all reviews with the count, long ones included" do
    @game.reviews.create!(user: users(:two), kind: "short", body: "Short.")
    @game.reviews.create!(user: @user, kind: "long", title: "T", body: "Long.")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".game-reviews a[href=?]", game_reviews_path(@game.igdb_id), text: "See all reviews (2)"
  end

  test "links to edit your own review instead of write" do
    review = @game.reviews.create!(user: @user, kind: "short", body: "Mine.")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".game-reviews a[href=?]", edit_game_review_path(@game.igdb_id, review), text: "Edit your review"
    assert_select ".game-reviews a", text: "Write your review", count: 0
  end

  test "hidden reviews are left out of the cards and the count, except for admins" do
    @game.reviews.create!(user: users(:two), kind: "short", body: "Fine take.")
    @game.reviews.create!(user: reviewer(1), kind: "short", body: "Rotten take.", hidden: true)

    sign_in(@user)
    get game_path(@game.igdb_id)
    assert_select ".review-card", 1
    assert_select ".review-card", text: /Rotten take/, count: 0
    assert_select ".game-reviews a", text: "See all reviews (1)"

    delete session_path
    @user.update!(admin: true)
    sign_in(@user)
    get game_path(@game.igdb_id)
    assert_select ".review-card", 2
    assert_select ".review-card .badge", text: "Hidden", count: 1
    assert_select ".game-reviews a", text: "See all reviews (2)"
  end

  test "the card row shows at most the 12 newest short reviews" do
    13.times do |i|
      @game.reviews.create!(user: reviewer(i), kind: "short", body: "Take #{i}.", created_at: (20 - i).minutes.ago)
    end
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".review-card", 12
    assert_select ".review-card", text: /Take 0\./, count: 0
    assert_select ".game-reviews a", text: "See all reviews (13)"
  end

  test "escapes HTML in a review card" do
    @game.reviews.create!(user: users(:two), kind: "short", body: "<script>alert(1)</script>")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".review-card script", 0
    assert_select ".review-card .review-body", text: "<script>alert(1)</script>"
  end

  test "a review card shows its author's star rating, when they rated the game" do
    @game.reviews.create!(user: @user, kind: "short", body: "Rated and reviewed.")
    @game.ratings.create!(user: @user, rating_halves: 9)
    @game.reviews.create!(user: users(:two), kind: "short", body: "Reviewed only.")
    sign_in(@user)
    get game_path(@game.igdb_id)

    assert_select ".review-card", 2
    assert_select ".review-card .stars[aria-label=?]", "4.5 stars", count: 1
    assert_select ".review-card", text: /Reviewed only/ do
      assert_select ".stars", 0
    end
  end
end
