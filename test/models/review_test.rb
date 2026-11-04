require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  def build(**attrs)
    Review.new({ user: @user, game: @game, kind: "short", body: "Great game." }.merge(attrs))
  end

  test "a short review needs only a body" do
    assert build.valid?
  end

  test "a short review may have a title" do
    assert build(title: "Loved it").valid?
  end

  test "a long review needs a title" do
    review = build(kind: "long", title: "")
    assert_not review.valid?
    assert_includes review.errors[:title], "can't be blank"
    assert build(kind: "long", title: "A deep dive").valid?
  end

  test "requires a body" do
    review = build(body: "")
    assert_not review.valid?
    assert_includes review.errors[:body], "can't be blank"
  end

  test "kind must be short or long" do
    review = build(kind: "epic")
    assert_not review.valid?
    assert_includes review.errors[:kind], "is not included in the list"
    assert_not build(kind: nil).valid?
  end

  test "a short review is capped at 280 characters" do
    assert build(body: "a" * 280).valid?
    review = build(body: "a" * 281)
    assert_not review.valid?
    assert_includes review.errors[:body], "is too long (maximum is 280 characters)"
  end

  test "a long review is capped at 1000 characters" do
    assert build(kind: "long", title: "T", body: "a" * 1000).valid?
    assert_not build(kind: "long", title: "T", body: "a" * 1001).valid?
  end

  test "the same text is fine as long but too long as short" do
    body = "a" * 500
    assert_not build(body: body).valid?
    assert build(kind: "long", title: "T", body: body).valid?
  end

  test "title is capped at 100 characters" do
    assert_not build(title: "t" * 101).valid?
    assert build(title: "t" * 100).valid?
  end

  test "a user can review a game only once" do
    build.save!
    dup = build(kind: "long", title: "Again")

    assert_not dup.valid?
    assert_includes dup.errors[:game_id], "has already been reviewed"
  end

  test "different users can review the same game" do
    build.save!
    assert build(user: users(:two)).valid?
  end

  test "the short scope returns only short reviews" do
    short = build.tap(&:save!)
    build(user: users(:two), kind: "long", title: "T").save!

    assert_equal [ short ], Review.short.to_a
  end

  test "short? and long? reflect the kind" do
    assert build.short?
    assert_not build.long?
    assert build(kind: "long").long?
  end

  test "the database enforces the kind and one review per user and game" do
    assert_raises(ActiveRecord::StatementInvalid) { build(kind: "epic").save!(validate: false) }

    build.save!
    assert_raises(ActiveRecord::RecordNotUnique) { build.dup.save!(validate: false) }
  end

  # --- moderation ----------------------------------------------------------

  test "visible leaves out hidden reviews" do
    shown = build.tap(&:save!)
    build(user: users(:two), hidden: true).save!

    assert_equal [ shown ], Review.visible.to_a
  end

  test "needing_attention is the reported reviews and the edited-while-hidden ones, each once" do
    clean = build.tap(&:save!)
    reported = build(user: users(:two)).tap(&:save!)
    Report.create!(user: users(:one), review: reported, reason: "spam")
    # A second report on the same review must not list it twice.
    other = User.create!(first_name: "Al", last_name: "Gore", username: "al", email_address: "al@example.com", password: "password1234")
    Report.create!(user: other, review: reported, reason: "abusive")
    settled = Review.create!(user: other, game: @game, kind: "short", body: "Hidden, decided.", hidden: true)
    other_game = Game.create!(igdb_id: 2000, name: "Other", refreshed_at: Time.current)
    edited = Review.create!(user: other, game: other_game, kind: "short", body: "Hidden, edited.", hidden: true, awaiting_review: true)

    assert_equal [ reported, edited ].sort_by(&:id), Review.needing_attention.sort_by(&:id)
    assert_not_includes Review.needing_attention, clean
    assert_not_includes Review.needing_attention, settled
  end

  test "hidden_and_settled is hidden reviews with nothing waiting on a moderator" do
    settled = build(hidden: true).tap(&:save!)
    edited = build(user: users(:two), hidden: true, awaiting_review: true).tap(&:save!)
    build_visible = Review.create!(user: User.create!(first_name: "Al", last_name: "Gore", username: "al", email_address: "al@example.com", password: "password1234"),
                                   game: @game, kind: "short", body: "Fine.")

    assert_equal [ settled ], Review.hidden_and_settled.to_a
    assert_not_includes Review.hidden_and_settled, edited
    assert_not_includes Review.hidden_and_settled, build_visible
  end

  test "editing a hidden review's text sends it back to the moderators" do
    review = build(hidden: true).tap(&:save!)

    review.update!(body: "Reworded.")

    assert review.reload.awaiting_review?
  end

  test "editing a visible review, or a hidden one without changing it, does not" do
    visible = build.tap(&:save!)
    visible.update!(body: "Reworded.")
    assert_not visible.reload.awaiting_review?

    hidden = build(user: users(:two), hidden: true).tap(&:save!)
    hidden.update!(body: hidden.body)
    assert_not hidden.reload.awaiting_review?
  end

  test "hide! hides it, clears the reports and takes it off the to-do list" do
    review = build(user: users(:two)).tap(&:save!)
    Report.create!(user: users(:one), review: review, reason: "spam")

    review.hide!

    assert review.reload.hidden?
    assert_equal 0, review.reports.count
    assert_not_includes Review.needing_attention, review
    assert_includes Review.hidden_and_settled, review
  end

  test "restore! unhides it and clears the reports and the edited flag" do
    review = build(user: users(:two)).tap(&:save!)
    Report.create!(user: users(:one), review: review, reason: "spam")
    review.update!(hidden: true, awaiting_review: true)

    review.restore!

    assert_not review.reload.hidden?
    assert_not review.awaiting_review?
    assert_equal 0, review.reports.count
  end

  test "keep_hidden! keeps it hidden and takes it off the to-do list" do
    review = build(hidden: true, awaiting_review: true).tap(&:save!)

    review.keep_hidden!

    assert review.reload.hidden?
    assert_not review.awaiting_review?
    assert_not_includes Review.needing_attention, review
  end

  test "dismiss_reports! clears the reports and leaves the review as it was" do
    review = build(user: users(:two)).tap(&:save!)
    Report.create!(user: users(:one), review: review, reason: "spam")

    review.dismiss_reports!

    assert_equal 0, review.reports.count
    assert_not review.reload.hidden?
  end
end
