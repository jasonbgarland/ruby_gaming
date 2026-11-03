import { Controller } from "@hotwired/stimulus"

// Enhances the review form: shows a live character count against the limit
// for the chosen kind (short or long) and says whether a title is needed.
// The model still enforces both rules; this only helps the writer see them.
//
//   <form data-controller="review-form"
//         data-review-form-short-limit-value="280"
//         data-review-form-long-limit-value="1000">
//     <input type="radio" data-review-form-target="kind" data-action="change->review-form#update">
//     <textarea data-review-form-target="body" data-action="input->review-form#update">
//     <small data-review-form-target="count"></small>
//     <small data-review-form-target="titleHint"></small>
export default class extends Controller {
  static targets = [ "kind", "body", "count", "titleHint" ]
  static values = { shortLimit: Number, longLimit: Number }

  connect() {
    this.update()
  }

  update() {
    const kind = this.kind
    const limit = kind === "long" ? this.longLimitValue : this.shortLimitValue
    const length = this.bodyTarget.value.length

    this.bodyTarget.maxLength = limit
    this.countTarget.textContent = `${length} / ${limit} characters`
    this.titleHintTarget.textContent = kind === "long" ? "Required for a long review." : "Optional for a short take."
  }

  // The checked radio's value, defaulting to short.
  get kind() {
    const checked = this.kindTargets.find((radio) => radio.checked)
    return checked ? checked.value : "short"
  }
}
