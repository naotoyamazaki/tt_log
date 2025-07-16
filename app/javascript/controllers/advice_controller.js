import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]
  static values = { id: Number, url: String }

  connect() {
    this.checkAdvice()
    this.interval = setInterval(() => this.checkAdvice(), 3000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  checkAdvice() {
    fetch(this.urlValue)
      .then(response => response.json())
      .then(data => {
        if (data.advice) {
          this.textTarget.textContent = data.advice
          clearInterval(this.interval)
        }
      })
      .catch(error => console.error(error))
  }
}
