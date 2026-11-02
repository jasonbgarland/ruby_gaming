require "test_helper"

class RatingsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    # refreshed_at is current, so nothing calls IGDB.
    @game = Game.create!(igdb_id: 1022, name: "The Legend of Zelda", refreshed_at: Time.current)
  end

  def rate(halves, game: @game)
    post game_rating_path(game.igdb_id), params: { rating_halves: halves }
  end

  test "create requires authentication" do
    rate 8

    assert_redirected_to new_session_path
    assert_equal 0, Rating.count
  end

  test "create saves the rating and returns to the game page" do
    sign_in(@user)

    assert_difference -> { @user.ratings.count }, 1 do
      rate 9
    end

    assert_redirected_to game_path(@game.igdb_id)
    assert_equal "Rated The Legend of Zelda 4.5 stars.", flash[:notice]
    assert_equal 9, @user.ratings.find_by!(game: @game).rating_halves
  end

  test "rating again changes the existing rating instead of adding one" do
    sign_in(@user)
    rate 4

    assert_no_difference -> { Rating.count } do
      rate 10
    end

    assert_equal 10, @user.ratings.find_by!(game: @game).rating_halves
  end

  test "create rejects values outside 1-10" do
    sign_in(@user)

    [ 0, 11, "abc", "", "4.5" ].each do |bad|
      assert_no_difference -> { Rating.count } do
        rate bad
      end
      assert_redirected_to game_path(@game.igdb_id)
      assert flash[:alert].present?, "expected an alert for #{bad.inspect}"
    end
  end

  test "ratings are per user" do
    @other_user.ratings.create!(game: @game, rating_halves: 3)
    sign_in(@user)
    rate 8

    assert_equal 3, @other_user.ratings.find_by!(game: @game).rating_halves
    assert_equal 2, @game.ratings.count
  end

  test "create for an unknown game is a 404" do
    sign_in(@user)

    post game_rating_path(999_999), params: { rating_halves: 8 }

    assert_response :not_found
  end

  test "destroy requires authentication" do
    rating = @other_user.ratings.create!(game: @game, rating_halves: 3)

    delete game_rating_path(@game.igdb_id)

    assert_redirected_to new_session_path
    assert Rating.exists?(rating.id)
  end

  test "destroy clears only the signed-in user's rating" do
    mine = @user.ratings.create!(game: @game, rating_halves: 8)
    theirs = @other_user.ratings.create!(game: @game, rating_halves: 3)
    sign_in(@user)

    delete game_rating_path(@game.igdb_id)

    assert_redirected_to game_path(@game.igdb_id)
    assert_not Rating.exists?(mine.id)
    assert Rating.exists?(theirs.id)
  end

  test "destroy with no rating is harmless" do
    sign_in(@user)

    assert_no_difference -> { Rating.count } do
      delete game_rating_path(@game.igdb_id)
    end
    assert_redirected_to game_path(@game.igdb_id)
  end
end
