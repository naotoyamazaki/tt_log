import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.buttonTargets.forEach(btn => { 
      btn.innerHTML = '<i class="fa-solid fa-eye"></i>'
      btn.setAttribute("aria-pressed", "false")
      btn.setAttribute("aria-label", "パスワードを表示")
    })
  }

  toggle(event) {
    const btn = event.currentTarget
    const targetName = btn.dataset.targetInput
    const input = this.inputTargets.find(el => el.dataset.inputName === targetName) || this.inputTarget
    if (!input) return

    const isHidden = input.type === "password"
    input.type = isHidden ? "text" : "password"

    btn.innerHTML = isHidden 
      ? '<i class="fa-solid fa-eye-slash"></i>'
      : '<i class="fa-solid fa-eye"></i>'

    btn.setAttribute("aria-pressed", String(isHidden))
    btn.setAttribute("aria-label", isHidden ? "パスワードを非表示" : "パスワードを表示")
  }
}
