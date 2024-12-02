import { Controller } from "@hotwired/stimulus"
import Autocomplete from "@hotwired/stimulus-autocomplete"

export default class extends Controller {
  connect() {
    console.log("Autocomplete controller connected"); // ログを追加
    new Autocomplete(this.element, {
      // オプションをここに設定
      input: this.element.querySelector("input"),
      url: this.urlValue,
    })
  }
}
