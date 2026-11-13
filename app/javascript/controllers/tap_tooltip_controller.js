import { Controller } from "@hotwired/stimulus"

// [data-tap-tooltip] を持つ要素をタップすると、その要素の上に説明を表示する。
// data-tap-tooltip-sticky="true" の場合は、別の場所をタップするまで表示し続ける。
export default class extends Controller {
  connect() {
    this.tip = null
    this.timer = null
    this._onClick = this.onClick.bind(this)
    this._hide = this.hide.bind(this)
    this.element.addEventListener("click", this._onClick)
    window.addEventListener("scroll", this._hide, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("click", this._onClick)
    window.removeEventListener("scroll", this._hide)
    this.hide()
  }

  onClick(event) {
    const target = event.target.closest("[data-tap-tooltip]")
    if (!target) {
      this.hide()
      return
    }

    // 同じ要素の再タップは閉じる
    if (this.tip && this.currentTarget === target) {
      this.hide()
      return
    }
    this.show(target)
  }

  show(target) {
    this.hide()
    this.currentTarget = target

    const tip = document.createElement("div")
    tip.className = "tap-tooltip"
    tip.setAttribute("role", "tooltip")
    tip.textContent = target.dataset.tapTooltip
    tip.style.cssText = "position:fixed;top:-9999px;left:-9999px;"
    document.body.appendChild(tip)

    const rect = target.getBoundingClientRect()
    const margin = 4
    let top = rect.top - tip.offsetHeight - 8
    if (top < margin) top = rect.bottom + 8
    const centerX = rect.left + rect.width / 2
    const left = Math.max(margin, Math.min(centerX - tip.offsetWidth / 2, window.innerWidth - tip.offsetWidth - margin))
    tip.style.top = `${top}px`
    tip.style.left = `${left}px`
    this.tip = tip

    if (target.dataset.tapTooltipSticky !== "true") {
      this.timer = setTimeout(() => this.hide(), 1500)
    }
  }

  hide() {
    if (this.timer) clearTimeout(this.timer)
    this.timer = null
    if (this.tip) this.tip.remove()
    this.tip = null
    this.currentTarget = null
  }
}
