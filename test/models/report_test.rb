require "test_helper"

class ReportTest < ActiveSupport::TestCase
  setup do
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
    @review = Review.create!(user: users(:one), game: @game, kind: "short", body: "Great.")
  end

  test "a reason from the list is valid" do
    assert Report.new(user: users(:two), review: @review, reason: "spam").valid?
  end

  test "every listed reason is accepted" do
    Report::REASONS.each_key do |reason|
      assert Report.new(user: users(:two), review: @review, reason: reason).valid?, reason
    end
  end

  test "an unknown or missing reason is invalid" do
    assert_not Report.new(user: users(:two), review: @review, reason: "rude").valid?
    assert_not Report.new(user: users(:two), review: @review, reason: nil).valid?
  end

  test "a user can report a review only once" do
    Report.create!(user: users(:two), review: @review, reason: "spam")
    again = Report.new(user: users(:two), review: @review, reason: "abusive")
    assert_not again.valid?
    assert_includes again.errors[:review_id], "has already been reported"
  end

  test "the database also refuses a duplicate report" do
    Report.create!(user: users(:two), review: @review, reason: "spam")
    assert_raises(ActiveRecord::RecordNotUnique) do
      Report.new(user: users(:two), review: @review, reason: "spam").save!(validate: false)
    end
  end

  test "you can't report your own review" do
    report = Report.new(user: users(:one), review: @review, reason: "spam")
    assert_not report.valid?
    assert_includes report.errors[:review], "can't be your own"
  end

  test "reviews are not hidden and users are not admins by default" do
    assert_not @review.hidden?
    assert_not users(:one).admin?
  end

  test "deleting a user deletes the reports they made" do
    Report.create!(user: users(:two), review: @review, reason: "spam")
    assert_difference "Report.count", -1 do
      users(:two).destroy
    end
  end

  test "deleting a user deletes reports of the reviews they wrote" do
    Report.create!(user: users(:two), review: @review, reason: "spam")
    assert_difference [ "Report.count", "Review.count" ], -1 do
      users(:one).destroy
    end
  end

  test "deleting a review deletes its reports" do
    Report.create!(user: users(:two), review: @review, reason: "spam")
    assert_difference "Report.count", -1 do
      @review.destroy
    end
  end
end
