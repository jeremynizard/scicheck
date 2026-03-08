import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "overlay"]

  submit() {
    this.submitTarget.disabled = true
    this.overlayTarget.classList.remove("hidden")
  }
}
