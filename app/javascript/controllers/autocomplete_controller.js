import { Controller } from "stimulus"
import Autocomplete from "stimulus-autocomplete"

export default class extends Controller {
  connect() {
    new Autocomplete(this.element, {
      // オプションをここに設定
      input: this.element.querySelector("input"),
      url: this.urlValue,
    })
  }
}
