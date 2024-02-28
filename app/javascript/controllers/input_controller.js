import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clear(event) {
    event.preventDefault();
    this.element.querySelector('input[type="search"]').value = "";
  }
}
