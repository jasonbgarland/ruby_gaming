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

  test "rating_stars draws five stars, filling whole and half stars" do
    stars = Nokogiri::HTML.fragment(rating_stars(Rating.new(rating_halves: 9))).at_css(".stars")

    assert_equal "img", stars["role"]
    assert_equal "4.5 stars", stars["aria-label"]
    assert_equal %w[ star-full star-full star-full star-full star-half ],
                 stars.css(".star").map { |star| star["class"].split.last }
  end

  test "rating_stars pads with empty stars" do
    classes = Nokogiri::HTML.fragment(rating_stars(Rating.new(rating_halves: 2))).css(".star").map { |star| star["class"].split.last }

    assert_equal %w[ star-full star-empty star-empty star-empty star-empty ], classes
    classes = Nokogiri::HTML.fragment(rating_stars(Rating.new(rating_halves: 1))).css(".star").map { |star| star["class"].split.last }
    assert_equal %w[ star-half star-empty star-empty star-empty star-empty ], classes
    classes = Nokogiri::HTML.fragment(rating_stars(Rating.new(rating_halves: 10))).css(".star").map { |star| star["class"].split.last }
    assert_equal %w[ star-full ] * 5, classes
  end
end
