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
  net_or_edge: 'ネットorエッジ',
  service_ace: 'サービスエース',
  receive_ace: 'レシーブエース',
  receive_miss: 'レシーブミス'
}

const ATTACK_STYLES = Object.keys(BATTING_STYLE_NAMES).filter(s => s !== 'serve' && s !== 'receive')

const SERVE_LENGTHS = { long: 'ロング', half_long: 'ハーフロング', short: 'ショート' }

const SERVE_SPIN_NAMES = { 0: '下回転', 1: '上回転', 2: 'ナックル', 3: '順横回転', 4: '逆横回転' }

const DECIDED_AT_LABELS = { attack_ball: '攻撃', follow_ball: '続球', rally: 'ラリー' }

export default class extends Controller {
  static targets = [
    "serverSelect", "serverIndicator", "firstServerField",
    "currentScore", "originIndicator",
    "stepServeLength", "stepServeSpins", "stepServeAttack",
    "stepReceiveStyle", "stepReceiveAttack", "stepResult",
    "serveAttackButtons", "receiveStyleButtons", "receiveAttackButtons",
    "patternList", "serialized", "endGameBtn"
  ]

  static values = {
    initialFirstServer: String
  }

  connect() {
    this.patterns = []
    this.firstServer = null
    this.currentStep = null

    // 現在入力中のパターン (ステップ途中の状態)
    this.draft = {}
    this.selectedSpins = []

    if (this.hasInitialFirstServerValue && this.initialFirstServerValue) {
      this.firstServer = this.initialFirstServerValue
    }

    this.renderAttackButtons()
    this.renderPatternList()
    this.updateScore()
    this.updateEndGameButton()
    this.serializePatterns()
    this.updateServerUI()
  }

  // ========== サーバー選択 ==========

  selectServer(event) {
    this.firstServer = event.currentTarget.dataset.server
    this.updateServerUI()
    this.showStep('origin')
    this.serializePatterns()
  }

  updateServerUI() {
    const hasServer = !!this.firstServer
    if (this.hasServerSelectTarget) {
      this.serverSelectTarget.classList.toggle('d-none', hasServer)
    }
    if (this.hasServerIndicatorTarget) {
      this.serverIndicatorTarget.classList.toggle('d-none', !hasServer)
      this.serverIndicatorTarget.textContent = this.getServerLabel()
    }
  }

  getServerLabel() {
    const current = this.getCurrentServer()
    if (!current) return ''
    return current === 'player' ? '🏓 自分のサーブ中' : '🏓 相手のサーブ中'
  }

  getCurrentServer() {
    if (!this.firstServer) return null
    const total = this.patterns.length
    let isFirstServerTurn
    if (total < 20) {
      isFirstServerTurn = Math.floor(total / 2) % 2 === 0
    } else {
      isFirstServerTurn = total % 2 === 0
    }
    return isFirstServerTurn ? this.firstServer : (this.firstServer === 'player' ? 'opponent' : 'player')
  }

  // ========== ステップ表示制御 ==========

  showStep(step) {
    this.currentStep = step
    const allSteps = [
      'stepServeLength', 'stepServeSpins', 'stepServeAttack',
      'stepReceiveStyle', 'stepReceiveAttack', 'stepResult'
    ]
    allSteps.forEach(s => {
      if (this[`has${s.charAt(0).toUpperCase() + s.slice(1)}Target`]) {
        this[`${s}Target`].classList.add('d-none')
      }
    })

    if (step === 'origin') {
      const origin = this.getOrigin()
      this.draft.origin = origin
      if (this.hasOriginIndicatorTarget) {
        this.originIndicatorTarget.textContent = origin === 'serve' ? '自分のサーブ' : '相手のサーブ（レシーブ）'
        this.originIndicatorTarget.classList.remove('d-none')
      }
      if (origin === 'serve') {
        if (this.hasStepServeLengthTarget) this.stepServeLengthTarget.classList.remove('d-none')
      } else {
        if (this.hasStepReceiveStyleTarget) this.stepReceiveStyleTarget.classList.remove('d-none')
      }
    } else if (step === 'spins') {
      this.selectedSpins = []
      this.updateSpinButtons()
      if (this.hasStepServeSpinsTarget) this.stepServeSpinsTarget.classList.remove('d-none')
    } else if (step === 'serve_attack') {
      if (this.hasStepServeAttackTarget) this.stepServeAttackTarget.classList.remove('d-none')
    } else if (step === 'receive_attack') {
      if (this.hasStepReceiveAttackTarget) this.stepReceiveAttackTarget.classList.remove('d-none')
    } else if (step === 'result') {
      if (this.hasStepResultTarget) this.stepResultTarget.classList.remove('d-none')
      this.updateResultButtonLabels()
    }
  }

  getOrigin() {
    const current = this.getCurrentServer()
    return current === 'player' ? 'serve' : 'receive'
  }

  // ========== 各ステップの入力 ==========

  selectServeLength(event) {
    this.draft.serve_length = event.currentTarget.dataset.length
    this.showStep('spins')
  }

  toggleSpin(event) {
    const spin = parseInt(event.currentTarget.dataset.spin)
    const idx = this.selectedSpins.indexOf(spin)
    if (idx === -1) {
      const exclusions = { 0: 1, 1: 0, 3: 4, 4: 3 }
      if (exclusions[spin] !== undefined) {
        this.selectedSpins = this.selectedSpins.filter(s => s !== exclusions[spin])
      }
      this.selectedSpins.push(spin)
    } else {
      this.selectedSpins.splice(idx, 1)
    }
    this.updateSpinButtons()
  }

  updateSpinButtons() {
    if (!this.hasStepServeSpinsTarget) return
    const buttons = this.stepServeSpinsTarget.querySelectorAll('[data-spin]')
    buttons.forEach(btn => {
      const spin = parseInt(btn.dataset.spin)
      btn.classList.toggle('active', this.selectedSpins.includes(spin))
    })
  }

  confirmSpins() {
    this.draft.serve_spins = [...this.selectedSpins]
    this.showStep('serve_attack')
  }

  selectServeAttack(event) {
    this.draft.attack_style = event.currentTarget.dataset.style
    this.showStep('result')
  }

  selectReceiveStyle(event) {
    this.draft.receive_style = event.currentTarget.dataset.style
    this.showStep('receive_attack')
  }

  selectReceiveAttack(event) {
    this.draft.attack_style = event.currentTarget.dataset.style
    this.showStep('result')
  }

  selectResult(event) {
    const won = event.currentTarget.dataset.won === 'true'
    const decidedAt = event.currentTarget.dataset.decidedAt

    this._commitPattern({
      origin: this.draft.origin,
      serve_length: this.draft.serve_length || null,
      serve_spins: this.draft.serve_spins || [],
      receive_style: this.draft.receive_style || null,
      attack_style: this.draft.attack_style,
      decided_at: decidedAt,
      won: won
    })
  }

  selectServiceAce() {
    this._commitPattern({
      origin: this.draft.origin,
      serve_length: this.draft.serve_length || null,
      serve_spins: this.draft.serve_spins || [],
      receive_style: null,
      attack_style: 'service_ace',
      decided_at: 'attack_ball',
      won: true
    })
  }

  selectReceiveAce() {
    this._commitPattern({
      origin: this.draft.origin,
      serve_length: null,
      serve_spins: [],
      receive_style: this.draft.receive_style || null,
      attack_style: 'receive_ace',
      decided_at: 'attack_ball',
      won: true
    })
  }

  selectReceiveMiss() {
    this._commitPattern({
      origin: this.draft.origin,
      serve_length: null,
      serve_spins: [],
      receive_style: this.draft.receive_style || null,
      attack_style: 'receive_miss',
      decided_at: 'attack_ball',
      won: false
    })
  }

  _commitPattern(pattern) {
    this.patterns.push(pattern)
    this.draft = {}
    this.selectedSpins = []
    this.showStep('origin')
    this.renderPatternList()
    this.updateScore()
    this.updateEndGameButton()
    this.serializePatterns()
    this.dispatchScoreUpdated()
  }

  // ========== undo ==========

  undo() {
    // まだ pattern が確定していない途中状態を1つ前に戻す
    if (this.currentStep === 'origin' || this.currentStep === null) {
      // パターンが1件以上あれば最後を取り消す
      if (this.patterns.length === 0) return
      this.patterns.pop()
      this.draft = {}
      this.selectedSpins = []
      this.renderPatternList()
      this.updateScore()
      this.updateEndGameButton()
      this.serializePatterns()
      this.dispatchScoreUpdated()
      this.showStep('origin')
    } else if (this.currentStep === 'spins') {
      this.draft.serve_length = null
      this.showStep('origin')
    } else if (this.currentStep === 'serve_attack') {
      this.showStep('spins')
    } else if (this.currentStep === 'receive_attack') {
      this.draft.receive_style = null
      this.showStep('origin')
    } else if (this.currentStep === 'result') {
      if (this.draft.origin === 'serve') {
        this.showStep('serve_attack')
      } else {
        this.showStep('receive_attack')
      }
    }
  }

  // ========== レンダリング ==========

  renderAttackButtons() {
    const regularStyles = ATTACK_STYLES.filter(s => s !== 'service_ace' && s !== 'receive_ace' && s !== 'receive_miss')

    const serviceAceBtn = `<button type="button" class="btn rally-style-btn rally-style-btn--ace"
      data-action="click->serve-receive-input#selectServiceAce">サービスエース</button>`
    const serveHtml = serviceAceBtn + regularStyles.map(style => {
      const name = BATTING_STYLE_NAMES[style] || style
      return `<button type="button" class="btn rally-style-btn"
        data-action="click->serve-receive-input#selectServeAttack"
        data-style="${style}">${name}</button>`
    }).join('')

    if (this.hasServeAttackButtonsTarget) this.serveAttackButtonsTarget.innerHTML = serveHtml

    const receiveHtml = regularStyles.map(style => {
      const name = BATTING_STYLE_NAMES[style] || style
      return `<button type="button" class="btn rally-style-btn"
        data-action="click->serve-receive-input#selectReceiveStyle"
        data-style="${style}">${name}</button>`
    }).join('')

    if (this.hasReceiveStyleButtonsTarget) this.receiveStyleButtonsTarget.innerHTML = receiveHtml

    const receiveAceBtn = `<button type="button" class="btn rally-style-btn rally-style-btn--ace"
      data-action="click->serve-receive-input#selectReceiveAce">レシーブエース</button>`
    const receiveMissBtn = `<button type="button" class="btn rally-style-btn rally-style-btn--miss"
      data-action="click->serve-receive-input#selectReceiveMiss">レシーブミス</button>`
    const receiveAttackHtml = receiveAceBtn + receiveMissBtn + regularStyles.map(style => {
      const name = BATTING_STYLE_NAMES[style] || style
      return `<button type="button" class="btn rally-style-btn"
        data-action="click->serve-receive-input#selectReceiveAttack"
        data-style="${style}">${name}</button>`
    }).join('')

    if (this.hasReceiveAttackButtonsTarget) this.receiveAttackButtonsTarget.innerHTML = receiveAttackHtml
  }

  renderPatternList() {
    if (!this.hasPatternListTarget) return
    if (this.patterns.length === 0) {
      this.patternListTarget.innerHTML = '<div class="rally-list-empty">まだパターンが入力されていません</div>'
      return
    }

    const items = [...this.patterns].reverse().map((p, revIdx) => {
      const idx = this.patterns.length - revIdx
      const wonLabel = p.won ? '自分の得点' : '相手の得点'
      const wonClass = p.won ? 'rally-item-player' : 'rally-item-opponent'
      const originLabel = p.origin === 'serve' ? 'サーブ' : 'レシーブ'
      const lengthLabel = p.serve_length ? (SERVE_LENGTHS[p.serve_length] || p.serve_length) : ''
      const spinsLabel = (p.serve_spins || []).map(s => SERVE_SPIN_NAMES[s] || s).join('/')
      const attackLabel = BATTING_STYLE_NAMES[p.attack_style] || p.attack_style
      const decidedLabel = DECIDED_AT_LABELS[p.decided_at] || p.decided_at
      const detail = p.origin === 'serve'
        ? `${originLabel}(${lengthLabel} ${spinsLabel}) → ${attackLabel} [${decidedLabel}]`
        : `${originLabel} → ${attackLabel} [${decidedLabel}]`
      const isFirst = revIdx === 0
      return `<div class="rally-item ${wonClass}">
        <span class="rally-item-seq">${idx}本目</span>
        <span class="rally-item-detail">${wonLabel} ← ${detail}</span>
        ${isFirst ? '<button type="button" class="btn btn-sm rally-undo-btn" data-action="click->serve-receive-input#undo">↩ 取り消し</button>' : ''}
      </div>`
    }).join('')

    this.patternListTarget.innerHTML = items
  }

  updateResultButtonLabels() {
    if (!this.hasStepResultTarget) return
    const isReceive = this.draft.origin === 'receive'
    const labels = isReceive
      ? {
          'true-attack_ball': '4球目で自分が得点',
          'false-attack_ball': '4球目で自分が失点',
          'true-follow_ball': '6球目で自分が得点',
          'false-follow_ball': '6球目で自分が失点',
          'true-rally': '7球目以降で得点',
          'false-rally': '7球目以降で失点'
        }
      : {
          'true-attack_ball': '3球目で自分が得点',
          'false-attack_ball': '3球目ミスで失点',
          'true-follow_ball': '5球目で自分が得点',
          'false-follow_ball': '5球目ミスで失点',
          'true-rally': '7球目以降で得点',
          'false-rally': '7球目以降で失点'
        }
    this.stepResultTarget.querySelectorAll('[data-decided-at]').forEach(btn => {
      const key = `${btn.dataset.won}-${btn.dataset.decidedAt}`
      if (labels[key]) btn.textContent = labels[key]
    })
  }

  updateScore() {
    const playerScore = this.patterns.filter(p => p.won).length
    const opponentScore = this.patterns.filter(p => !p.won).length

    if (this.hasCurrentScoreTarget) {
      this.currentScoreTarget.textContent = `${playerScore} - ${opponentScore}`
    }

    this.updateServerUI()
  }

  updateEndGameButton() {
    if (!this.hasEndGameBtnTarget) return
    if (!this.firstServer) {
      this.endGameBtnTarget.disabled = true
      return
    }
    const playerScore = this.patterns.filter(p => p.won).length
    const opponentScore = this.patterns.filter(p => !p.won).length
    const canEnd = Math.max(playerScore, opponentScore) >= 11 &&
                   Math.abs(playerScore - opponentScore) >= 2
    this.endGameBtnTarget.disabled = !canEnd
  }

  serializePatterns() {
    if (this.hasSerializedTarget) {
      this.serializedTarget.value = JSON.stringify(this.patterns)
    }
    if (this.hasFirstServerFieldTarget) {
      this.firstServerFieldTarget.value = this.firstServer || ''
    }
  }

  dispatchScoreUpdated() {
    const playerScore = this.patterns.filter(p => p.won).length
    const opponentScore = this.patterns.filter(p => !p.won).length
    this.element.dispatchEvent(new CustomEvent('rally:scoreUpdated', {
      bubbles: true,
      detail: { playerScore, opponentScore }
    }))
  }
}
