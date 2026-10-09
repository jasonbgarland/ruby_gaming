require "application_system_test_case"

class GamesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @user.collections.create!(title: "Wishlist")

    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json,
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(
      status: 200,
      body: [ { "id" => 1022, "name" => "The Legend of Zelda",
               "summary" => "An adventure.",
               "platforms" => [ { "name" => "NES" }, { "name" => "Switch" } ] } ].to_json,
    )
  end

  # The results sit inside a Turbo Frame; this checks the link breaks out of
  # it and loads the whole game page (integration tests can't see that).
  test "clicking a search result opens the game page" do
    sign_in_via_browser
    visit games_search_path
    fill_in "q", with: "zelda"
    click_on "Search"

    click_on "The Legend of Zelda"

    assert_current_path game_path(1022)
    assert_selector "h1", text: "The Legend of Zelda"
    assert_text "An adventure."
  end

  test "add the game to a collection from its page, then remove it" do
    sign_in_via_browser
    visit game_path(1022)
    assert_text "This game isn't in any of your collections yet."

    select "Wishlist", from: "Collection"
    select "Switch", from: "Platform"
    click_on "Add"

    assert_current_path game_path(1022)
    assert_text "Added The Legend of Zelda (Switch) to Wishlist."
    assert_selector ".your-stuff li", text: "Wishlist (Switch)"

    click_on "Remove"

    assert_current_path game_path(1022)
    assert_text "Removed The Legend of Zelda (Switch)."
    assert_text "This game isn't in any of your collections yet."
  end
end
