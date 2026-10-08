import { Controller } from "@hotwired/stimulus"

// Submits the form it is attached to shortly after the user stops typing.
//
//   <form data-controller="autosubmit" data-autosubmit-min-length-value="3">
//     <input data-action="input->autosubmit#submit">
//   </form>
//
// Each keystroke restarts the timer, so only a pause triggers a submit.
// Text shorter than minLength never auto-submits; pressing Enter or the
// submit button still submits it, since that doesn't go through here.
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 },
    minLength: { type: Number, default: 0 }
  }

  submit(event) {
    clearTimeout(this.timeout)
    if (event.target.value.trim().length < this.minLengthValue) return

    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
