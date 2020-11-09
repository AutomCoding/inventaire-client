import log_ from 'lib/loggers'
import preq from 'lib/preq'
import waitForCheck from '../lib/wait_for_check'
import documentLang from '../lib/document_lang'
import showViews from '../lib/show_views'
import TopBar from './top_bar'
import initModal from '../lib/modal'
import initFlashMessage from '../lib/flash_message'
import ConfirmationModal from './confirmation_modal'
import screen_ from 'lib/screen'
import appLayoutTemplate from './templates/app_layout.hbs'

export default Marionette.LayoutView.extend({
  template: appLayoutTemplate,

  el: '#app',

  regions: {
    topBar: '#topBar',
    main: 'main',
    modal: '#modalContent'
  },

  ui: {
    topBar: '#topBar',
    flashMessage: '#flashMessage'
  },

  events: {
    'click .showEntityEdit': 'showEntityEdit',
    'click .showEntityCleanup': 'showEntityCleanup'
  },

  behaviors: {
    General: {},
    PreventDefault: {},
    Dropdown: {}
  },

  initialize () {
    _.extend(this, showViews)

    this.render()
    app.commands.setHandlers({
      'show:loader': this.showLoader,
      'main:fadeIn' () { return app.layout.main.$el.hide().fadeIn(200) },
      'show:feedback:menu': this.showFeedbackMenu,
      'show:donate:menu': this.showDonateMenu,
      'ask:confirmation': this.askConfirmation.bind(this),
      'history:back' (options) {
        // Go back only if going back means staying in the app
        if (Backbone.history.last.length > 0) {
          return window.history.back()
        } else {
          return options?.fallback?.()
        }
      }
    })

    app.reqres.setHandlers({
      waitForCheck,
      'post:feedback': postFeedback
    })

    documentLang(this.$el, app.user.lang)

    initModal()
    initFlashMessage.call(this)
    // wait for the app to be initiated before listening to resize events
    // to avoid firing a meaningless event at initialization
    app.request('waitForNetwork').then(initWindowResizeEvents)

    return $('body').on('click', app.vent.Trigger('body:click'))
  },

  // /!\ app_layout is never 'show'n so onShow never gets fired
  // but it gets rendered
  onRender () {
    this.topBar.show(new TopBar())
  },

  askConfirmation (options) {
    this.modal.show(new ConfirmationModal(options))
  }
})

const initWindowResizeEvents = function () {
  let previousScreenMode = screen_.isSmall()
  const resizeEnd = function () {
    const newScreenMode = screen_.isSmall()
    if (newScreenMode !== previousScreenMode) {
      previousScreenMode = newScreenMode
      app.vent.trigger('screen:mode:change')
    }
  }

  const resize = _.debounce(resizeEnd, 150)
  $(window).resize(resize)
}

// params = { subject, message, uris, context, unknownUser }
const postFeedback = function (params) {
  if (params.context == null) { params.context = {} }
  params.context.location = document.location.pathname + document.location.search
  log_.info(params, 'posting feedback')
  return preq.post(app.API.feedback, params)
}
