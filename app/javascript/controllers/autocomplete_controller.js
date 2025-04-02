import { Controller } from "@hotwired/stimulus";
import Autocomplete from "@hotwired/stimulus-autocomplete";

export default class extends Controller {
  static targets = ["input"];

  connect() {
    console.log("Autocomplete controller connected"); // デバッグ用ログ

    // オートコンプリートを初期化
    new Autocomplete(this.element, {
      input: this.inputTarget,
      url: this.urlValue,
    });
  }
}
