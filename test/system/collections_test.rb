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

  def stub_igdb_zelda
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json,
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(
      status: 200,
      body: [ { "id" => 1022, "name" => "The Legend of Zelda",
               "platforms" => [ { "name" => "NES" }, { "name" => "Switch" } ] } ].to_json,
    )
  end

  test "search, add a game on a platform, then remove it" do
    stub_igdb_zelda
    sign_in_via_browser
    visit collection_path(@collection)

    fill_in "Game name", with: "zelda"
    click_on "Search"
    assert_text "The Legend of Zelda"

    select "Switch", from: "Platform"
    click_on "Add"
    assert_text "Added The Legend of Zelda (Switch) to Wishlist."
    assert_equal [ "Switch" ], @collection.collection_games.pluck(:platform)

    click_on "Remove"
    assert_text "Removed The Legend of Zelda (Switch)."
    assert_equal 0, @collection.collection_games.count
  end

  test "results appear as you type, without clicking Search" do
    stub_igdb_zelda
    sign_in_via_browser
    visit games_search_path

    # No click on Search: the autosubmit controller submits after a pause.
    fill_in "Game name", with: "zelda"
    assert_text "The Legend of Zelda"
  end

  test "typing fewer than 3 characters doesn't auto-search, but Search still works" do
    stub_igdb_zelda
    sign_in_via_browser
    visit games_search_path

    fill_in "Game name", with: "ze"
    sleep 0.6 # longer than the 300ms debounce, so an auto-submit would have fired
    assert_no_text "The Legend of Zelda"
    assert_not_requested :post, "https://api.igdb.com/v4/games"

    click_on "Search"
    assert_text "The Legend of Zelda"
  end

  test "searching swaps results inside the frame without a full page load" do
    stub_igdb_zelda
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

  def stub_igdb_no_results
    stub_request(:post, "https://id.twitch.tv/oauth2/token").to_return(
      status: 200, body: { access_token: "t", expires_in: 5_184_000 }.to_json,
    )
    stub_request(:post, "https://api.igdb.com/v4/games").to_return(status: 200, body: [].to_json)
  end

  # After an Add the page redirects back with the same results still
  # showing, so only search when there are none. (Re-searching would swap
  # the frame under the platform picker mid-test and reset its selection.)
  def search_and_add(platform)
    unless page.has_button?("Add", wait: 0)
      fill_in "Game name", with: "zelda"
      click_on "Search"
      assert_text "The Legend of Zelda"
    end
    select platform, from: "Platform"
    click_on "Add"
  end

  test "adding the same game on the same platform twice shows an error" do
    stub_igdb_zelda
    sign_in_via_browser
    visit collection_path(@collection)

    search_and_add("Switch")
    assert_text "Added The Legend of Zelda (Switch) to Wishlist."

    search_and_add("Switch")
    assert_text "Game has already been added on that platform"
    assert_equal 1, @collection.collection_games.count
  end

  test "the same game on two platforms can be added, and removed one at a time" do
    stub_igdb_zelda
    sign_in_via_browser
    visit collection_path(@collection)

    search_and_add("Switch")
    assert_text "Added The Legend of Zelda (Switch) to Wishlist."
    search_and_add("NES")
    assert_text "Added The Legend of Zelda (NES) to Wishlist."
    assert_equal %w[ NES Switch ], @collection.collection_games.order(:platform).pluck(:platform)

    # The platform <p> in the collection list holds only the platform name
    # (search results' <p> also lists the year and every platform).
    within(:xpath, "//li[.//p[normalize-space()='NES']]") { click_on "Remove" }
    assert_text "Removed The Legend of Zelda (NES)."
    assert_equal [ "Switch" ], @collection.collection_games.pluck(:platform)
  end

  test "a duplicate collection title shows an error and keeps what was typed" do
    sign_in_via_browser
    visit new_collection_path

    fill_in "Title", with: "Wishlist"
    click_on "Create Collection"

    assert_text "Title has already been taken"
    assert_field "Title", with: "Wishlist"
    assert_equal 1, @user.collections.where(title: "Wishlist").count
  end

  test "typing in the search box keeps focus and the full text across live searches" do
    stub_igdb_zelda
    sign_in_via_browser
    visit collection_path(@collection)

    box = find_field("Game name")
    box.send_keys("zel")
    assert_text "The Legend of Zelda"

    # Keep typing after the first results swapped in; if the swap had
    # replaced the input, focus and the typed text would be lost.
    box.send_keys("da")
    sleep 0.6 # let the second debounced search run and swap its results in

    assert_field "Game name", with: "zelda"
    assert_equal "q", page.evaluate_script("document.activeElement.id")
  end

  test "a search with no matches says so instead of erroring" do
    stub_igdb_no_results
    sign_in_via_browser
    visit collection_path(@collection)

    fill_in "Game name", with: "qzxwv"
    click_on "Search"

    assert_text "No results for “qzxwv”."
  end
end
