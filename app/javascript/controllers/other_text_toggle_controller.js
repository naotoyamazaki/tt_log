import { Controller } from "@hotwired/stimulus"

// select の値が特定の値（デフォルト "other"）のときだけ、
// 連動するテキスト欄を表示する汎用controller。
export default class extends Controller {
  static targets = ["select", "text"]
  static values = { showValue: { type: String, default: "other" } }

  connect() {
    this.toggle()
  }

  toggle() {
    const shouldShow = this.selectTarget.value === this.showValueValue
    this.textTargets.forEach(target => {
      target.classList.toggle("d-none", !shouldShow)
    })
  }
}
