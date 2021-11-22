import log_ from 'lib/loggers'
import preq from 'lib/preq'
import waitForCheck from '../lib/wait_for_check'
import initDocumentLang from '../lib/document_lang'
import showViews from '../lib/show_views'
import TopBar from './top_bar'
import initModal from '../lib/modal'
import initFlashMessage from '../lib/flash_message'
import ConfirmationModal from './confirmation_modal'
import screen_ from 'lib/screen'
import appLayoutTemplate from './templates/app_layout.hbs'
import assert_ from 'app/lib/assert_types'
import Dropdown from 'behaviors/dropdown'
import General from 'behaviors/general'
import PreventDefault from 'behaviors/prevent_default'

export default Marionette.View.extend({
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
    'click .showEntityCleanup': 'showEntityCleanup',
    'click .showEntityHistory': 'showEntityHistory',
  },

  behaviors: {
    Dropdown,
    General,
    PreventDefault,
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
          window.history.back()
        } else {
          options?.fallback?.()
        }
      }
    })

    app.reqres.setHandlers({
      waitForCheck,
      'post:feedback': postFeedback
    })

    initDocumentLang(app.user.lang)

    initModal()
    initFlashMessage.call(this)
    // wait for the app to be initiated before listening to resize events
    // to avoid firing a meaningless event at initialization
    app.request('waitForNetwork').then(initWindowResizeEvents)

    $('body').on('click', app.vent.Trigger('body:click'))
  },

  // /!\ app_layout is never 'show'n so onShow never gets fired
  // but it gets rendered
  onRender () {
    this.showChildView('topBar', new TopBar())
  },

  askConfirmation (options) {
    const { action, formAction } = options
    assert_.function(action)
    if (formAction != null) assert_.function(formAction)
    this.showChildView('modal', new ConfirmationModal(options))
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
  if (params.context == null) params.context = {}
  params.context.location = document.location.pathname + document.location.search
  log_.info(params, 'posting feedback')
  return preq.post(app.API.feedback, params)
}
