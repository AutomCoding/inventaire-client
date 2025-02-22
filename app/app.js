import { isNonEmptyString } from '#lib/boolean_tests'
import BindedPartialBuilder from '#lib/binded_partial_builder'
import { updateRouteMetadata } from '#lib/metadata/update'
import error_ from '#lib/error'
import { routeSection, currentRouteWithQueryString } from '#lib/location'
import { channel, reqres, request, execute } from './radio.js'
import { dropLeadingSlash } from '#lib/utils'
import { scrollToElement } from '#lib/screen'

let initialUrlNavigateAlreadyCalled = false
let lastNavigateTimestamp = 0

const App = Marionette.Application.extend({
  initialize () {
    Backbone.history.last = []

    // Mapping backbone.radio concepts on the formerly used backbone-wreqr concepts
    this.vent = channel
    // `commands` and `requests` now use the same handler store
    this.reqres = this.commands = reqres
    // but keep there specific behaviors when called, namely,
    // `request` returns something
    this.request = request
    // `execute` doesn't
    this.execute = execute

    this.Execute = BindedPartialBuilder(this, 'execute')
    this.Request = BindedPartialBuilder(this, 'request')
    this.vent.Trigger = BindedPartialBuilder(this.vent, 'trigger')

    this.once('start', onceStart)

    const navigateFromModel = function (model, pathAttribute = 'pathname', options = {}) {
      // Polymorphism
      if (_.isObject(pathAttribute)) {
        options = pathAttribute
        pathAttribute = options.pathAttribute || 'pathname'
      }

      options.metadata = model.updateMetadata()
      const route = model.get(pathAttribute)
      if (isNonEmptyString(route)) {
        this.navigate(route, options)
      } else {
        error_.report(`navigation model has no ${pathAttribute} attribute`, model)
      }
    }

    // Make it a binded function so that it can be reused elsewhere without
    // having to bind it again
    this.navigateFromModel = navigateFromModel.bind(this)
  },

  navigate (route, options = {}) {
    // Close the modal if it was open
    // If the next view just opened the modal, this will be ignored
    app.execute('modal:close')
    // Update metadata before testing if the route changed
    // so that a call from a router action would trigger a metadata update
    // but not affect the history (due to the early return hereafter)
    updateRouteMetadata(route, options.metadata)
    // Easing code mutualization by firing app.navigate, even when the module
    // simply reacted to the requested URL
    if (route === currentRouteWithQueryString()) {
      // Trigger a route event for the first URL, so that views listening
      // on the route:change event can update accordingly
      if (!initialUrlNavigateAlreadyCalled) {
        this.vent.trigger('route:change', routeSection(route), route)
        initialUrlNavigateAlreadyCalled = true
      }
      return
    }

    // a starting slash would be corrected by the Backbone.Router
    // but routeSection relies on the route not starting by a slash.
    // it can't just thrown an error as pathnames commonly require to start
    // by a slash to avoid being interpreted as relative pathnames
    route = dropLeadingSlash(route)

    this.vent.trigger('route:change', routeSection(route), route)
    route = this.request('querystring:keep', route)
    Backbone.history.last.unshift(route)

    // Replace last route in history when several navigation happen quickly
    // so that hitting "Previous" correctly brings back to the last page
    // where a user action triggered a page change
    const now = Date.now()
    if (now < lastNavigateTimestamp + 200) options.replace = true
    lastNavigateTimestamp = now

    Backbone.history.navigate(route, options)
    const { pageSectionElement, preventScrollTop } = options
    if (pageSectionElement) {
      scrollToElement(pageSectionElement, options)
    } else if (!preventScrollTop) {
      scrollToPageTop()
    }
  },

  navigateAndLoad (route, options = {}) {
    options.trigger = true
    this.navigate(route, options)
  },

  navigateReplace (route, options) {
    if (!options) options = {}
    options.replace = true
    this.navigate(route, options)
  }
})

const onceStart = function () {
  Backbone.history.start({ pushState: true })

  // Backbone.history 'route' event seem to be only triggered
  // when 'previous' is hit. it isn't very clear why,
  // but it allows to notify functionalities depending on the route
  Backbone.history.on('route', onPreviousRoute)
}

const onPreviousRoute = function () {
  // Close the modal if it was open
  // If a modal is actually displayed in the previous route, it should
  // be reopen by the view being reshown
  app.execute('modal:close')

  const route = currentRouteWithQueryString()
  app.vent.trigger('route:change', routeSection(route), route)
}

const app = window.app = new App()

export default app

const scrollToPageTop = () => window.scrollTo(0, 0)
