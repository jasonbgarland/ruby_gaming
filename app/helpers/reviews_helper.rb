module ReviewsHelper
  SPOILER = /\|\|(.+?)\|\|/m
  # Click, or Enter/Space from the keyboard, toggles the spoiler.
  SPOILER_ACTIONS = "click->spoiler#toggle keydown.enter->spoiler#toggle:prevent keydown.space->spoiler#toggle:prevent"

  # Renders a review's body as safe HTML. Order matters: escape everything the
  # user typed first, then wrap ||spoiler|| runs in our own span, so the only
  # markup in the output is markup we generated. Line breaks are preserved.
  def review_body(review)
    escaped = ERB::Util.html_escape(review.body.to_s)
    marked = escaped.gsub(SPOILER) do
      tag.span(Regexp.last_match(1).html_safe, class: "spoiler", role: "button", tabindex: 0,
               aria: { pressed: false }, data: { controller: "spoiler", action: SPOILER_ACTIONS })
    end
    simple_format(marked.html_safe, {}, sanitize: false)
  end
end
