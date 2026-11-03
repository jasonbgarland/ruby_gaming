require "test_helper"

class ReviewsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    # refreshed_at is current, so nothing calls IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  def review_params(**overrides)
    { review: { kind: "short", title: "", body: "Loved it." }.merge(overrides) }
  end

  # --- authentication ------------------------------------------------------

  test "every action requires authentication" do
    review = @game.reviews.create!(user: @user, kind: "short", body: "Hi.")

    get game_reviews_path(@game.igdb_id)
    assert_redirected_to new_session_path
    get new_game_review_path(@game.igdb_id)
    assert_redirected_to new_session_path
    post game_reviews_path(@game.igdb_id), params: review_params
    assert_redirected_to new_session_path
    get edit_game_review_path(@game.igdb_id, review)
    assert_redirected_to new_session_path
    patch game_review_path(@game.igdb_id, review), params: review_params
    assert_redirected_to new_session_path
    delete game_review_path(@game.igdb_id, review)
    assert_redirected_to new_session_path
  end

  # --- index ---------------------------------------------------------------

  test "index lists everyone's reviews, with edit and delete only on your own" do
    sign_in(@user)
    @game.reviews.create!(user: @user, kind: "short", body: "My own take.")
    @game.reviews.create!(user: @other_user, kind: "long", title: "A deep dive", body: "Their long thoughts.")

    get game_reviews_path(@game.igdb_id)

    assert_response :success
    assert_select "h1", text: /Reviews of The Legend of Zelda/
    assert_select ".review", 2
    assert_select ".review-body", text: "My own take."
    assert_select ".review-title", text: "A deep dive"
    assert_select ".review-actions", 1
    assert_select "a", text: "Edit your review"
  end

  test "index offers to write a review when you have none, and says when there are none" do
    sign_in(@user)

    get game_reviews_path(@game.igdb_id)

    assert_select "a[href=?]", new_game_review_path(@game.igdb_id), text: "Write your review"
    assert_select ".review-empty"
  end

  test "index shows the newest review first" do
    sign_in(@user)
    @game.reviews.create!(user: @user, kind: "short", body: "Older.", created_at: 2.days.ago)
    @game.reviews.create!(user: @other_user, kind: "short", body: "Newer.", created_at: 1.day.ago)

    get game_reviews_path(@game.igdb_id)

    assert_equal [ "Newer.", "Older." ], css_select(".review-body").map(&:text)
  end

  test "index escapes HTML in a review" do
    sign_in(@user)
    @game.reviews.create!(user: @other_user, kind: "short", body: "<script>alert(1)</script>")

    get game_reviews_path(@game.igdb_id)

    assert_select ".review-body script", 0
    assert_select ".review-body", text: "<script>alert(1)</script>"
  end

  test "an unknown game is a 404" do
    sign_in(@user)

    get game_reviews_path(999_999)

    assert_response :not_found
  end

  # --- new / create --------------------------------------------------------

  test "new shows the form with short selected" do
    sign_in(@user)

    get new_game_review_path(@game.igdb_id)

    assert_response :success
    assert_select "input[type=radio][name='review[kind]'][value=short][checked]"
    assert_select "input[type=radio][name='review[kind]'][value=long]"
    assert_select "textarea[name='review[body]']"
  end

  test "new sends you to edit when you already have a review" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "short", body: "Hi.")

    get new_game_review_path(@game.igdb_id)

    assert_redirected_to edit_game_review_path(@game.igdb_id, review)
  end

  test "create saves a short review and returns to the reviews page" do
    sign_in(@user)

    assert_difference -> { @user.reviews.count }, 1 do
      post game_reviews_path(@game.igdb_id), params: review_params
    end

    assert_redirected_to game_reviews_path(@game.igdb_id)
    assert_equal "Posted your review of The Legend of Zelda.", flash[:notice]
    review = @user.reviews.find_by!(game: @game)
    assert_equal "short", review.kind
    assert_equal "Loved it.", review.body
  end

  test "create saves a long review with a title" do
    sign_in(@user)

    post game_reviews_path(@game.igdb_id), params: review_params(kind: "long", title: "A deep dive", body: "a" * 900)

    assert_redirected_to game_reviews_path(@game.igdb_id)
    assert_equal "long", @user.reviews.find_by!(game: @game).kind
  end

  test "create re-renders the form with errors for an invalid review" do
    sign_in(@user)

    assert_no_difference -> { Review.count } do
      post game_reviews_path(@game.igdb_id), params: review_params(kind: "long", title: "", body: "")
    end

    assert_response :unprocessable_entity
    assert_select ".error-messages li", text: /Title can't be blank/
    assert_select ".error-messages li", text: /Body can't be blank/
  end

  test "create rejects a short review over 280 characters" do
    sign_in(@user)

    assert_no_difference -> { Review.count } do
      post game_reviews_path(@game.igdb_id), params: review_params(body: "a" * 281)
    end

    assert_response :unprocessable_entity
  end

  test "create refuses a second review of the same game" do
    sign_in(@user)
    @game.reviews.create!(user: @user, kind: "short", body: "First.")

    assert_no_difference -> { Review.count } do
      post game_reviews_path(@game.igdb_id), params: review_params(body: "Second.")
    end

    assert_response :unprocessable_entity
    assert_select ".error-messages li", text: /already been reviewed/
  end

  test "create ignores a user_id or game_id in the params" do
    sign_in(@user)
    other_game = Game.create!(igdb_id: 2000, name: "Other", refreshed_at: Time.current)

    post game_reviews_path(@game.igdb_id), params: { review: { kind: "short", body: "Mine.", user_id: @other_user.id, game_id: other_game.id } }

    review = Review.last
    assert_equal @user, review.user
    assert_equal @game, review.game
  end

  # --- edit / update -------------------------------------------------------

  test "edit shows the form filled in" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "long", title: "A deep dive", body: "Thoughts.")

    get edit_game_review_path(@game.igdb_id, review)

    assert_response :success
    assert_select "input[name='review[title]'][value='A deep dive']"
    assert_select "textarea[name='review[body]']", text: "Thoughts."
    assert_select "input[type=radio][value=long][checked]"
  end

  test "update changes the review and can switch its kind" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "short", body: "Quick.")

    patch game_review_path(@game.igdb_id, review), params: review_params(kind: "long", title: "Now longer", body: "Fuller thoughts.")

    assert_redirected_to game_reviews_path(@game.igdb_id)
    assert_equal "Updated your review of The Legend of Zelda.", flash[:notice]
    review.reload
    assert_equal "long", review.kind
    assert_equal "Now longer", review.title
  end

  test "update re-renders the form with errors for an invalid change" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "short", body: "Quick.")

    patch game_review_path(@game.igdb_id, review), params: review_params(kind: "long", title: "")

    assert_response :unprocessable_entity
    assert_equal "short", review.reload.kind
  end

  test "you cannot edit or update someone else's review" do
    sign_in(@user)
    review = @game.reviews.create!(user: @other_user, kind: "short", body: "Theirs.")

    get edit_game_review_path(@game.igdb_id, review)
    assert_response :not_found

    patch game_review_path(@game.igdb_id, review), params: review_params(body: "Hijacked.")
    assert_response :not_found
    assert_equal "Theirs.", review.reload.body
  end

  test "a review is only found under its own game" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "short", body: "Mine.")
    other_game = Game.create!(igdb_id: 2000, name: "Other", refreshed_at: Time.current)

    get edit_game_review_path(other_game.igdb_id, review)

    assert_response :not_found
  end

  # --- destroy -------------------------------------------------------------

  test "destroy deletes your review and returns to the game page" do
    sign_in(@user)
    review = @game.reviews.create!(user: @user, kind: "short", body: "Bye.")

    assert_difference -> { Review.count }, -1 do
      delete game_review_path(@game.igdb_id, review)
    end

    assert_redirected_to game_path(@game.igdb_id)
    assert_equal "Deleted your review of The Legend of Zelda.", flash[:notice]
  end

  test "you cannot delete someone else's review" do
    sign_in(@user)
    review = @game.reviews.create!(user: @other_user, kind: "short", body: "Theirs.")

    assert_no_difference -> { Review.count } do
      delete game_review_path(@game.igdb_id, review)
    end

    assert_response :not_found
  end
end
