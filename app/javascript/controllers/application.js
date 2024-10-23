import { Turbo } from "@hotwired/turbo-rails"
Turbo.start()

import { Application } from "@hotwired/stimulus"
const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
