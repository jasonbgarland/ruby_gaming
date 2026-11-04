module ReviewsHelper
  SPOILER = /\|\|(.+?)\|\|/m

  # Renders a review's body as safe HTML. Order matters: escape everything the
  # user typed first, then wrap ||spoiler|| runs in our own span, so the only
  # markup in the output is markup we generated. Line breaks are preserved.
  def review_body(review)
    escaped = ERB::Util.html_escape(review.body.to_s)
    marked = escaped.gsub(SPOILER) do
      tag.span(Regexp.last_match(1).html_safe, class: "spoiler", data: { spoiler_target: "text" })
    end
    simple_format(marked.html_safe, {}, sanitize: false)
  end
end
