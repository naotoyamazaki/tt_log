import { application } from "./application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
import { Autocomplete } from "@hotwired/stimulus-autocomplete"

application.register("autocomplete", Autocomplete)
eagerLoadControllersFrom("controllers", application)
