import { Controller } from "@hotwired/stimulus"

// フォーム送信時にボタンを無効化し「生成中…」を表示する（二重送信防止）
export default class extends Controller {
  static targets = ["button"]
  static values = { text: { type: String, default: "生成中…" } }

  connect() {
    this.element.addEventListener("submit", () => this.start())
  }

  start() {
    this.buttonTargets.forEach((button) => {
      // 送信自体を妨げないよう、次のtickで無効化する
      setTimeout(() => {
        button.disabled = true
        if (button.tagName === "INPUT") {
          button.value = this.textValue
        } else {
          button.textContent = this.textValue
        }
      }, 0)
    })
  }
}
