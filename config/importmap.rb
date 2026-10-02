pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@5.3.2/dist/js/bootstrap.esm.js"
# Chart.js 4系最新の安定版（jspm.io CDN経由）。成長ダッシュボードの折れ線グラフ描画に使用。
pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.4.4/auto/auto.js"
# chart.js/auto が内部依存する色計算ライブラリ（裸のimport指定子のためimportmapへの明示pinが必須）
pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.4/dist/color.esm.js"

pin "custom_number_input", to: "custom_number_input.js", preload: true
pin "@hotwired/stimulus-autocomplete", to: "https://ga.jspm.io/npm:stimulus-autocomplete@3.1.0/src/autocomplete.js"
pin "advice_controller", to: "controllers/advice_controller.js"
