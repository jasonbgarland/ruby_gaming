module RatingsHelper
  # A read-only row of five stars (half stars included) for a Rating, labelled
  # for screen readers, e.g. "4.5 stars". The glyphs are drawn by CSS.
  def rating_stars(rating)
    full, half = rating.rating_halves.divmod(2)
    classes = Array.new(full, "star-full") + Array.new(half, "star-half")
    classes += Array.new(5 - classes.size, "star-empty")

    tag.span(class: "stars", role: "img", aria: { label: stars_label(rating) }) do
      safe_join(classes.map { |css_class| tag.span(class: "star #{css_class}", aria: { hidden: true }) })
    end
  end

  # "4.5 stars", "4 stars", "1 star"; takes a Rating or a number of stars.
  def stars_label(rating_or_stars)
    stars = rating_or_stars.respond_to?(:stars) ? rating_or_stars.stars : rating_or_stars
    text = number_with_precision(stars, precision: 1, strip_insignificant_zeros: true)
    "#{text} #{'star'.pluralize(stars == 1 ? 1 : 2)}"
  end
end
