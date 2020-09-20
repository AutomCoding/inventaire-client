getActionKey = require 'lib/get_action_key'
error_ = require 'lib/error'
forms_ = require 'modules/general/lib/forms'

module.exports = Marionette.ItemView.extend
  className: 'confirmationModal'
  template: require './templates/confirmation_modal'
  behaviors:
    SuccessCheck: {}
    AlertBox: {}
    ElasticTextarea: {}
    General: {}

  ui:
    no: '#no'
    yes: '#yes'
    altAction: '#altAction'

  serializeData: ->
    data = @options
    data.altAction or= 'altAction'
    data.yes or= 'yes'
    data.no or= 'no'
    data.yesButtonClass or= 'alert'
    data.canGoBack = @options.back?
    return data

  events:
    'click a#yes': 'yes'
    'click a#no': 'close'
    'click a#altAction': 'altAction'
    'keydown': 'changeButton'
    'click a#back': 'back'

  onShow: ->
    app.execute 'modal:open', null, @options.focus
    # trigger once the modal is done sliding down
    @setTimeout @ui.no.focus.bind(@ui.no), 600

  yes: ->
    { action, selector } = @options
    @confirming(action, selector)

  altAction: ->
    { altAction, selector } = @options
    @confirming(altAction, selector)

  confirming: (action, selector)->
    Promise.try @executeAction.bind(@)
    .then action
    .then @success.bind(@)
    .catch @error.bind(@)
    .finally @stopLoading.bind(null, selector)

  success: (res)->
    @$el.trigger 'check', @close.bind(@)
    return res

  error: (err)->
    _.error err, 'confirmation action err'
    @$el.trigger 'fail'
    error_.complete err, '.check', false
    forms_.catchAlert @, err

  close: ->
    if @options.back? then @options.back()
    else app.execute 'modal:close'

  stopLoading: (selector)->
    if selector? then $(selector).trigger('stopLoading')
    else _.warn 'confirmation modal: no selector was provided'

  executeAction: ->
    { formAction } = @options
    if formAction?
      formContent = @$el.find('#confirmationForm').val()
      if _.isNonEmptyString formContent
        return formAction formContent

  changeButton: (e)->
    key = getActionKey e
    switch key
      when 'left' then @ui.no.focus()
      when 'right' then @ui.yes.focus()

  back: -> @options.back()
