require "application_system_test_case"

class RatingsTest < ApplicationSystemTestCase
  setup do
    # refreshed_at is current, so the game page doesn't call IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  # The stars are radios drawn by CSS and submitted by a Stimulus controller;
  # only a real browser can click them and run that.
  test "rate a game with a half star, change it, then clear it" do
    sign_in_via_browser
    visit game_path(1022)
    assert_text "You haven't rated this game yet."
    assert_text "No ratings yet."

    find("label[for=rating_halves_9]").click
    assert_text "Rated The Legend of Zelda 4.5 stars."
    assert_text "You rated it 4.5 stars."
    assert_text "Average 4.5 stars from 1 rating."
    assert_checked_field "rating_halves_9", visible: :all

    find("label[for=rating_halves_2]").click
    assert_text "You rated it 1 star."
    assert_equal 2, users(:one).ratings.find_by!(game: @game).rating_halves

    click_on "Clear"
    assert_text "Cleared your rating of The Legend of Zelda."
    assert_text "You haven't rated this game yet."
    assert_text "No ratings yet."
    assert_equal 0, Rating.count
  end
end
