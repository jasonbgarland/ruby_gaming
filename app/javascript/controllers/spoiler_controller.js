import { Controller } from "@hotwired/stimulus"

// Hides a ||spoiler|| in a review until the reader clicks it; clicking again
// hides it. ReviewsHelper#review_body renders each spoiler as its own element,
// so the controller sits on the span itself. CSS does the hiding (.spoiler vs
// .spoiler.revealed); this only flips the class and tells screen readers.
//
//   <span class="spoiler" role="button" tabindex="0" aria-pressed="false"
//         data-controller="spoiler" data-action="click->spoiler#toggle">...</span>
export default class extends Controller {
  toggle() {
    const revealed = this.element.classList.toggle("revealed")
    this.element.setAttribute("aria-pressed", revealed)
  }
}
