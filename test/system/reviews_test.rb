require "application_system_test_case"

class ReviewsTest < ApplicationSystemTestCase
  setup do
    # refreshed_at is current, so the pages don't call IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  # The counter, the textarea limit and the title hint come from the
  # review-form Stimulus controller, so only a real browser can check them.
  test "the form counts characters against the limit for the chosen kind" do
    sign_in_via_browser
    visit new_game_review_path(1022)
    assert_text "0 / 280 characters"
    assert_text "Optional for a short take."

    fill_in "Your review", with: "Great game."
    assert_text "11 / 280 characters"

    # The textarea stops at the limit, so typing past it is cut off at 280.
    # rapid: false types every key; Capybara's default for long text pastes
    # most of it with JavaScript, which skips input events and maxlength.
    fill_in "Your review", with: "a" * 300, fill_options: { rapid: false }
    assert_text "280 / 280 characters"

    choose "Long review"
    assert_text "280 / 1000 characters"
    assert_text "Required for a long review."

    choose "Short take"
    assert_text "280 / 280 characters"
    assert_text "Optional for a short take."
  end

  test "write a short review, edit it into a long one, then delete it" do
    sign_in_via_browser
    visit new_game_review_path(1022)

    fill_in "Your review", with: "Quick take: loved it."
    click_on "Post review"
    assert_text "Posted your review of The Legend of Zelda."
    assert_text "Quick take: loved it."
    assert_equal "short", users(:one).reviews.find_by!(game: @game).kind

    click_on "Edit", match: :first
    assert_field "Your review", with: "Quick take: loved it."
    choose "Long review"
    fill_in "Title", with: "A proper write-up"
    fill_in "Your review", with: "Loved it, and here is why. " * 10
    click_on "Update review"
    assert_text "Updated your review of The Legend of Zelda."
    assert_text "A proper write-up"
    assert_text "Long review"
    assert_equal "long", users(:one).reviews.find_by!(game: @game).kind

    accept_confirm { click_on "Delete" }
    assert_text "Deleted your review of The Legend of Zelda."
    assert_equal 0, Review.count
  end

  # The game page is how people reach reviews: write one from there, then see
  # it as a card with a link to all reviews.
  test "write a review from the game page and see it as a card there" do
    sign_in_via_browser
    visit game_path(1022)
    assert_text "No short reviews yet."
    assert_no_link "See all reviews"

    click_on "Write your review"
    fill_in "Your review", with: "Charming from start to finish."
    click_on "Post review"
    assert_text "Posted your review of The Legend of Zelda."

    visit game_path(1022)
    within ".review-cards" do
      assert_text "Charming from start to finish."
      assert_text "ada"
    end
    assert_link "Edit your review"

    click_on "See all reviews (1)"
    assert_current_path game_reviews_path(1022)
    assert_text "Charming from start to finish."
  end
end
