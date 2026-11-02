require "test_helper"

class RatingsHelperTest < ActionView::TestCase
  test "stars_label formats whole and half stars" do
    assert_equal "4.5 stars", stars_label(4.5)
    assert_equal "4 stars", stars_label(4.0)
    assert_equal "1 star", stars_label(1.0)
    assert_equal "0.5 stars", stars_label(0.5)
  end

  test "stars_label accepts a Rating" do
    assert_equal "3.5 stars", stars_label(Rating.new(rating_halves: 7))
  end
end
