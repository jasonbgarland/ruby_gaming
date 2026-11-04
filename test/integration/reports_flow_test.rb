require "test_helper"

class ReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @author = users(:two)
    # refreshed_at is current, so nothing calls IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
    @review = @game.reviews.create!(user: @author, kind: "short", body: "A take.")
  end

  def report_path_for(review)
    game_review_report_path(@game.igdb_id, review)
  end

  # --- create --------------------------------------------------------------

  test "requires authentication" do
    post report_path_for(@review), params: { reason: "spam" }
    assert_redirected_to new_session_path
    assert_equal 0, Report.count
  end

  test "reports a review with a reason" do
    sign_in(@user)

    assert_difference "Report.count", 1 do
      post report_path_for(@review), params: { reason: "abusive" }
    end

    assert_redirected_to game_reviews_path(@game.igdb_id)
    assert_equal "Thanks, a moderator will take a look.", flash[:notice]
    report = Report.last
    assert_equal [ @user, @review, "abusive" ], [ report.user, report.review, report.reason ]
  end

  test "goes back to the page you were on" do
    sign_in(@user)

    post report_path_for(@review), params: { reason: "spam" }, headers: { "HTTP_REFERER" => game_url(@game.igdb_id) }

    assert_redirected_to game_url(@game.igdb_id)
  end

  test "an unknown or missing reason is refused" do
    sign_in(@user)

    assert_no_difference "Report.count" do
      post report_path_for(@review), params: { reason: "rude" }
      post report_path_for(@review), params: {}
    end

    assert_redirected_to game_reviews_path(@game.igdb_id)
    assert flash[:alert].present?
  end

  test "reporting the same review twice is refused" do
    sign_in(@user)
    post report_path_for(@review), params: { reason: "spam" }

    assert_no_difference "Report.count" do
      post report_path_for(@review), params: { reason: "abusive" }
    end

    assert_match(/already been reported/, flash[:alert])
  end

  test "you can't report your own review" do
    own = @game.reviews.create!(user: @user, kind: "short", body: "Mine.")
    sign_in(@user)

    assert_no_difference "Report.count" do
      post report_path_for(own), params: { reason: "spam" }
    end

    assert_match(/can't be your own/, flash[:alert])
  end

  test "a review hidden from you is a 404, and even an admin can't report a hidden one" do
    @review.update!(hidden: true)
    sign_in(@user)
    post report_path_for(@review), params: { reason: "spam" }
    assert_response :not_found

    delete session_path
    @user.update!(admin: true)
    sign_in(@user)
    assert_no_difference "Report.count" do
      post report_path_for(@review), params: { reason: "spam" }
    end
    assert_match(/already hidden/, flash[:alert])
  end

  test "a review on another game is a 404" do
    other = Game.create!(igdb_id: 2000, name: "Other", refreshed_at: Time.current)
    sign_in(@user)

    post game_review_report_path(other.igdb_id, @review), params: { reason: "spam" }

    assert_response :not_found
  end

  # --- the Report control --------------------------------------------------

  test "the reviews list offers Report on other people's reviews only" do
    @game.reviews.create!(user: @user, kind: "short", body: "Mine.")
    sign_in(@user)

    get game_reviews_path(@game.igdb_id)

    assert_select ".review", 2
    assert_select ".review-report", 1
    assert_select "form[action=?]", report_path_for(@review) do
      assert_select "select[name=reason] option[value]", Report::REASONS.size + 1 # + the "Why?" prompt
    end
  end

  test "the list and the game page say Reported once you have reported" do
    Report.create!(user: @user, review: @review, reason: "spam")
    sign_in(@user)

    get game_reviews_path(@game.igdb_id)
    assert_select ".review-reported", text: "Reported"
    assert_select ".review-report", 0

    get game_path(@game.igdb_id)
    assert_select ".review-card .review-reported", text: "Reported"
    assert_select ".review-card .review-report", 0
  end

  test "the game page offers Report on a card" do
    sign_in(@user)

    get game_path(@game.igdb_id)

    assert_select ".review-card .review-report form[action=?]", report_path_for(@review)
  end
end
