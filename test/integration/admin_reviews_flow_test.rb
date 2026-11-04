require "test_helper"

class AdminReviewsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(admin: true)
    @author = users(:two)
    @reporter = User.create!(first_name: "Al", last_name: "Gore", username: "al", email_address: "al@example.com", password: "password1234")
    # refreshed_at is current, so nothing calls IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
    @review = @game.reviews.create!(user: @author, kind: "short", body: "A rotten take.")
    Report.create!(user: @reporter, review: @review, reason: "abusive")
  end

  # --- access --------------------------------------------------------------

  test "every action requires authentication" do
    get admin_reviews_path
    assert_redirected_to new_session_path
    patch hide_admin_review_path(@review)
    assert_redirected_to new_session_path
    assert_not @review.reload.hidden?
  end

  test "everything is a 404 for a non-admin, and nothing changes" do
    sign_in(@reporter)

    get admin_reviews_path
    assert_response :not_found
    patch hide_admin_review_path(@review)
    assert_response :not_found
    patch restore_admin_review_path(@review)
    assert_response :not_found
    patch keep_hidden_admin_review_path(@review)
    assert_response :not_found
    delete dismiss_admin_review_path(@review)
    assert_response :not_found

    assert_not @review.reload.hidden?
    assert_equal 1, @review.reports.count
  end

  test "the nav links to moderation for admins only" do
    sign_in(@admin)
    get root_path
    assert_select "nav a[href=?]", admin_reviews_path, text: "Moderation"

    delete session_path
    sign_in(@reporter)
    get root_path
    assert_select "nav a[href=?]", admin_reviews_path, count: 0
  end

  # --- the queue -----------------------------------------------------------

  test "the queue lists reported and edited-while-hidden reviews; settled hidden ones are listed apart" do
    @game.reviews.create!(user: @reporter, kind: "short", body: "A perfectly nice take.")
    other_game = Game.create!(igdb_id: 2000, name: "Other", refreshed_at: Time.current)
    other_game.reviews.create!(user: @author, kind: "short", body: "Hidden earlier.", hidden: true)
    third_game = Game.create!(igdb_id: 3000, name: "Third", refreshed_at: Time.current)
    third_game.reviews.create!(user: @author, kind: "short", body: "Hidden, then edited.", hidden: true, awaiting_review: true)
    sign_in(@admin)

    get admin_reviews_path

    assert_response :success
    assert_select ".moderation-queue .review", 2
    assert_select ".moderation-queue .review-body", text: "A rotten take."
    assert_select ".moderation-queue .review-body", text: "Hidden, then edited."
    assert_select ".moderation-queue .badge", text: "Edited since hidden", count: 1
    assert_select ".moderation-queue .report-list li", text: /Abusive or hateful.*al/
    assert_select ".moderation-hidden .review", 1
    assert_select ".moderation-hidden .review-body", text: "Hidden earlier."
    assert_select ".review-body", text: /perfectly nice/, count: 0
  end

  test "says so when there is nothing to look at" do
    Report.delete_all
    sign_in(@admin)

    get admin_reviews_path

    assert_select ".moderation-queue .review-empty"
    assert_select ".moderation-hidden .review-empty"
    assert_select ".review", 0
  end

  # --- actions -------------------------------------------------------------

  test "hide hides the review, clears its reports and moves it out of the queue" do
    sign_in(@admin)

    patch hide_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert_match(/Hid grace's review/, flash[:notice])
    assert @review.reload.hidden?
    assert_equal 0, @review.reports.count
    get admin_reviews_path
    assert_select ".moderation-queue .review", 0
    assert_select ".moderation-hidden .review", 1
  end

  test "restore unhides the review and clears the reports and the edited flag" do
    @review.update!(hidden: true, awaiting_review: true)
    sign_in(@admin)

    patch restore_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert_not @review.reload.hidden?
    assert_not @review.awaiting_review?
    assert_equal 0, @review.reports.count
  end

  test "keep hidden leaves it hidden and takes it out of the queue" do
    @review.update!(hidden: true, awaiting_review: true)
    sign_in(@admin)

    patch keep_hidden_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert_match(/Kept grace's review hidden/, flash[:notice])
    assert @review.reload.hidden?
    assert_not @review.awaiting_review?
    get admin_reviews_path
    assert_select ".moderation-queue .review", 0
    assert_select ".moderation-hidden .review", 1
  end

  test "dismiss clears the reports and leaves the review visible" do
    sign_in(@admin)

    delete dismiss_admin_review_path(@review)

    assert_redirected_to admin_reviews_path
    assert_not @review.reload.hidden?
    assert_equal 0, @review.reports.count
    get admin_reviews_path
    assert_select ".review", 0
  end

  test "the buttons depend on the review's state" do
    sign_in(@admin)

    # Visible and reported: Hide and Dismiss.
    get admin_reviews_path
    assert_select "form[action=?]", hide_admin_review_path(@review)
    assert_select "form[action=?]", dismiss_admin_review_path(@review)
    assert_select "form[action=?]", restore_admin_review_path(@review), count: 0
    assert_select "form[action=?]", keep_hidden_admin_review_path(@review), count: 0

    # Hidden and decided: Restore only.
    @review.hide!
    get admin_reviews_path
    assert_select "form[action=?]", restore_admin_review_path(@review)
    assert_select "form[action=?]", hide_admin_review_path(@review), count: 0
    assert_select "form[action=?]", dismiss_admin_review_path(@review), count: 0
    assert_select "form[action=?]", keep_hidden_admin_review_path(@review), count: 0

    # Hidden and edited: Restore and Keep hidden.
    @review.update!(body: "Reworded.")
    get admin_reviews_path
    assert_select "form[action=?]", restore_admin_review_path(@review)
    assert_select "form[action=?]", keep_hidden_admin_review_path(@review)
  end

  test "the full loop: hidden, edited by the author, back in the queue, kept hidden" do
    sign_in(@admin)
    patch hide_admin_review_path(@review)
    delete session_path

    sign_in(@author)
    patch game_review_path(@game.igdb_id, @review), params: { review: { kind: "short", title: "", body: "Reworded." } }
    delete session_path

    sign_in(@admin)
    get admin_reviews_path
    assert_select ".moderation-queue .review-body", text: "Reworded."
    patch keep_hidden_admin_review_path(@review)
    get admin_reviews_path
    assert_select ".moderation-queue .review", 0
  end

  test "a hidden review is gone for normal users and back after a restore" do
    sign_in(@admin)
    patch hide_admin_review_path(@review)
    delete session_path

    sign_in(@reporter)
    get game_reviews_path(@game.igdb_id)
    assert_select ".review-body", text: /rotten/, count: 0

    delete session_path
    sign_in(@admin)
    patch restore_admin_review_path(@review)
    delete session_path

    sign_in(@reporter)
    get game_reviews_path(@game.igdb_id)
    assert_select ".review-body", text: /rotten/
  end
end
