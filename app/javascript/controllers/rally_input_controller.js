import { Controller } from "@hotwired/stimulus"

const BATTING_STYLE_NAMES = {
  serve: 'サーブ',
  receive: 'レシーブ',
  fore_drive_vs_topspin: '対上回転フォアドライブ',
  back_drive_vs_topspin: '対上回転バックドライブ',
  fore_drive_vs_backspin: '対下回転フォアドライブ',
  back_drive_vs_backspin: '対下回転バックドライブ',
  fore_push: 'フォアツッツキ',
  back_push: 'バックツッツキ',
  fore_stop: 'フォアストップ',
  back_stop: 'バックストップ',
  fore_flick: 'フォアフリック',
  back_flick: 'バックフリック',
  chiquita: 'チキータ',
  fore_block: 'フォアブロック',
  back_block: 'バックブロック',
  fore_counter: 'フォアカウンター',
  back_counter: 'バックカウンター',
  fore_smash: 'フォアスマッシュ',
  back_smash: 'バックスマッシュ',
  net_or_edge: 'ネットorエッジ'
}

const BATTING_STYLES_PRIMARY = [
  'serve', 'fore_drive_vs_topspin', 'back_drive_vs_topspin',
  'fore_drive_vs_backspin', 'back_drive_vs_backspin',
  'fore_push', 'back_push', 'chiquita'
]

const BATTING_STYLES_ALL = Object.keys(BATTING_STYLE_NAMES).filter(s => s !== 'receive')

export default class extends Controller {
  static targets = [
    "step1", "step2", "styleButtons", "rallyList",
    "endGameBtn", "serialized", "currentScore",
    "showMore"
  ]

  static values = {
    initialRallies: String
  }

  connect() {
    this.rallies = []
    this.selectedWinner = null
    this.showingAll = false

    if (this.hasInitialRalliesValue && this.initialRalliesValue) {
      try {
        const initial = JSON.parse(this.initialRalliesValue)
        if (Array.isArray(initial)) {
          this.rallies = initial
        }
      } catch (_e) {
        // ignore parse errors
      }
    }

    this.renderStyleButtons()
    this.renderRallyList()
    this.updateScore()
    this.updateEndGameButton()
    this.serializeRallies()

    this.element.addEventListener("rally:getRallies", (e) => {
      e.detail.rallies = [...this.rallies]
    })
  }

  selectWinner(event) {
    this.selectedWinner = event.currentTarget.dataset.winner
    if (this.hasStep1Target) this.step1Target.classList.add("d-none")
    if (this.hasStep2Target) this.step2Target.classList.remove("d-none")
  }

  selectStyle(event) {
    const battingStyle = event.currentTarget.dataset.style
    if (!this.selectedWinner || !battingStyle) return

    this.rallies.push({ winner: this.selectedWinner, batting_style: battingStyle })
    this.selectedWinner = null

    if (this.hasStep2Target) this.step2Target.classList.add("d-none")
    if (this.hasStep1Target) this.step1Target.classList.remove("d-none")

    this.renderRallyList()
    this.updateScore()
    this.updateEndGameButton()
    this.serializeRallies()
    this.dispatchScoreUpdated()
  }

  undo() {
    if (this.rallies.length === 0) return
    this.rallies.pop()

    this.selectedWinner = null
    if (this.hasStep2Target) this.step2Target.classList.add("d-none")
    if (this.hasStep1Target) this.step1Target.classList.remove("d-none")

    this.renderRallyList()
    this.updateScore()
    this.updateEndGameButton()
    this.serializeRallies()
    this.dispatchScoreUpdated()
  }

  toggleShowMore() {
    this.showingAll = !this.showingAll
    this.renderStyleButtons()
    if (this.hasShowMoreTarget) {
      this.showMoreTarget.textContent = this.showingAll ? '閉じる ▲' : 'もっと見る ▼'
    }
  }

  renderStyleButtons() {
    if (!this.hasStyleButtonsTarget) return
    const styles = this.showingAll ? BATTING_STYLES_ALL : BATTING_STYLES_PRIMARY
    this.styleButtonsTarget.innerHTML = styles.map(style => {
      const name = BATTING_STYLE_NAMES[style] || style
      return `<button type="button" class="btn rally-style-btn"
        data-action="click->rally-input#selectStyle"
        data-style="${style}">${name}</button>`
    }).join('')
  }

  renderRallyList() {
    if (!this.hasRallyListTarget) return
    if (this.rallies.length === 0) {
      this.rallyListTarget.innerHTML = '<div class="rally-list-empty">まだラリーが入力されていません</div>'
      return
    }

    const items = [...this.rallies].reverse().map((rally, revIdx) => {
      const idx = this.rallies.length - revIdx
      const winnerLabel = rally.winner === 'player' ? '自分' : '相手'
      const winnerClass = rally.winner === 'player' ? 'rally-item-player' : 'rally-item-opponent'
      const styleName = BATTING_STYLE_NAMES[rally.batting_style] || rally.batting_style
      const isFirst = revIdx === 0
      return `<div class="rally-item ${winnerClass}">
        <span class="rally-item-seq">${idx}本目</span>
        <span class="rally-item-detail">${winnerLabel} ← ${styleName}</span>
        ${isFirst ? '<button type="button" class="btn btn-sm rally-undo-btn" data-action="click->rally-input#undo">↩ 取り消し</button>' : ''}
      </div>`
    }).join('')

    this.rallyListTarget.innerHTML = items
  }

  updateScore() {
    const playerScore = this.rallies.filter(r => r.winner === 'player').length
    const opponentScore = this.rallies.filter(r => r.winner === 'opponent').length

    if (this.hasCurrentScoreTarget) {
      this.currentScoreTarget.textContent = `${playerScore} - ${opponentScore}`
    }
  }

  updateEndGameButton() {
    if (!this.hasEndGameBtnTarget) return
    const playerScore = this.rallies.filter(r => r.winner === 'player').length
    const opponentScore = this.rallies.filter(r => r.winner === 'opponent').length
    const canEnd = Math.max(playerScore, opponentScore) >= 11 &&
                   Math.abs(playerScore - opponentScore) >= 2
    this.endGameBtnTarget.disabled = !canEnd
  }

  serializeRallies() {
    if (this.hasSerializedTarget) {
      this.serializedTarget.value = JSON.stringify(this.rallies)
    }
  }

  dispatchScoreUpdated() {
    const playerScore = this.rallies.filter(r => r.winner === 'player').length
    const opponentScore = this.rallies.filter(r => r.winner === 'opponent').length
    this.element.dispatchEvent(new CustomEvent('rally:scoreUpdated', {
      bubbles: true,
      detail: { playerScore, opponentScore }
    }))
  }
}
