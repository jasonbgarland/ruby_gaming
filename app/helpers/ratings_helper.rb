module RatingsHelper
  # "4.5 stars", "4 stars", "1 star"; takes a Rating or a number of stars.
  def stars_label(rating_or_stars)
    stars = rating_or_stars.respond_to?(:stars) ? rating_or_stars.stars : rating_or_stars
    text = number_with_precision(stars, precision: 1, strip_insignificant_zeros: true)
    "#{text} #{'star'.pluralize(stars == 1 ? 1 : 2)}"
  end
end
