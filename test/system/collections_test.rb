require "application_system_test_case"

class CollectionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @collection = @user.collections.create!(title: "Wishlist")
  end

  # System tests drive a real browser, so sign in through the real form
  # (integration tests can POST /session directly; a browser can't).
  def sign_in_via_browser
    visit new_session_path
    fill_in "Username or email", with: @user.email_address
    fill_in "Password", with: "password1234"
    click_on "Sign in"
    assert_text "Log out"
  end

  test "create, edit, and delete a collection" do
    sign_in_via_browser

    visit collections_path
    click_on "New collection"
    fill_in "Title", with: "Owned"
    click_on "Create Collection"
    assert_text "Owned"

    click_on "Edit"
    fill_in "Title", with: "Owned games"
    click_on "Update Collection"
    assert_text "Owned games"

    accept_confirm { click_on "Delete" }
    assert_current_path collections_path
    assert_no_text "Owned games"
  end

  test "dismissing the delete confirmation keeps the collection" do
    sign_in_via_browser
    visit collection_path(@collection)

    dismiss_confirm { click_on "Delete" }

    assert_current_path collection_path(@collection)
    assert_text "Wishlist"
    assert Collection.exists?(@collection.id)
  end

  test "searching swaps results inside the frame without a full page load" do
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json,
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(
      status: 200,
      body: [{ "id" => 1022, "name" => "The Legend of Zelda",
               "platforms" => [{ "name" => "NES" }] }].to_json,
    )

    sign_in_via_browser
    visit games_search_path

    # A marker set on the live `window` object survives a Turbo Frame swap
    # but is wiped by a full page load, so it proves which one happened.
    page.execute_script("window.notReloaded = true")

    fill_in "Game name", with: "zelda"
    click_on "Search"

    assert_text "The Legend of Zelda"
    assert page.evaluate_script("window.notReloaded"),
           "expected a Turbo Frame swap, but the page fully reloaded"
  end
end
