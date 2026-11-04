require "test_helper"

class ReviewsHelperTest < ActionView::TestCase
  def render_body(text)
    Nokogiri::HTML.fragment(review_body(Review.new(body: text)))
  end

  test "plain text passes through" do
    assert_equal "Great game", render_body("Great game").text.strip
    assert_empty render_body("Great game").css(".spoiler")
  end

  test "wraps ||text|| in a spoiler span" do
    spoilers = render_body("He ||dies at the end|| sadly").css(".spoiler")

    assert_equal [ "dies at the end" ], spoilers.map(&:text)
  end

  test "handles several spoilers in one review" do
    spoilers = render_body("||one|| and ||two||").css(".spoiler")

    assert_equal %w[ one two ], spoilers.map(&:text)
  end

  test "an unmatched || is left as typed" do
    fragment = render_body("odd || marker")

    assert_empty fragment.css(".spoiler")
    assert_includes fragment.text, "odd || marker"
  end

  test "escapes HTML, including inside spoilers" do
    fragment = render_body("<script>alert(1)</script> ||<b>x</b>||")

    assert_empty fragment.css("script")
    assert_empty fragment.css("b")
    assert_includes fragment.text, "<script>alert(1)</script>"
    assert_equal [ "<b>x</b>" ], fragment.css(".spoiler").map(&:text)
  end

  test "keeps line breaks" do
    assert_equal 2, render_body("line one\n\nline two").css("p").size
  end
end
