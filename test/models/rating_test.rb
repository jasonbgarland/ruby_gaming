require "test_helper"

class RatingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  test "valid with a rating from 1 to 10 half-stars" do
    [ 1, 5, 10 ].each do |halves|
      assert Rating.new(user: @user, game: @game, rating_halves: halves).valid?, "#{halves} should be valid"
    end
  end

  test "requires rating_halves" do
    rating = Rating.new(user: @user, game: @game)
    assert_not rating.valid?
    assert_includes rating.errors[:rating_halves], "can't be blank"
  end

  test "rejects values outside 1-10 and non-integers" do
    [ 0, 11, -1, 4.5 ].each do |halves|
      assert_not Rating.new(user: @user, game: @game, rating_halves: halves).valid?, "#{halves} should be invalid"
    end
  end

  test "a user can rate a game only once" do
    Rating.create!(user: @user, game: @game, rating_halves: 8)
    dup = Rating.new(user: @user, game: @game, rating_halves: 4)

    assert_not dup.valid?
    assert_includes dup.errors[:game_id], "has already been rated"
  end

  test "different users can rate the same game" do
    Rating.create!(user: @user, game: @game, rating_halves: 8)
    assert Rating.new(user: users(:two), game: @game, rating_halves: 6).valid?
  end

  test "stars converts half-stars to stars" do
    assert_equal 4.5, Rating.new(rating_halves: 9).stars
    assert_equal 0.5, Rating.new(rating_halves: 1).stars
  end

  test "the database also enforces the range and uniqueness" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Rating.new(user: @user, game: @game, rating_halves: 11).save!(validate: false)
    end
  end
end
