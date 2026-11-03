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
end
