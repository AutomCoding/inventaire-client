# REQUIRED:
# - ConfirmationModal behavior

behaviorsPlugin = require 'modules/general/plugins/behaviors'

events =
  'click .cancel': 'cancel'
  'click .discard': 'discard'
  'click .accept': 'accept'
  'click .request': 'send'
  'click .unfriend': 'unfriend'
  'click .invite': 'invite'
  'click .acceptRequest': 'acceptRequest'
  'click .refuseRequest': 'refuseRequest'

confirmUnfriend = ->
  confirmationText = _.i18n 'unfriend_confirmation',
    username: @model.get 'username'

  @$el.trigger 'askConfirmation',
    confirmationText: confirmationText
    warningText: null
    action: app.request.bind(app, 'unfriend', @model)

handlers =
  cancel: -> app.request 'request:cancel', @model
  discard: -> app.request 'request:discard', @model
  accept: -> app.request 'request:accept', @model
  send: ->
    username = @model.get 'username'
    if app.request 'require:loggedIn', "inventory/#{username}"
      app.request 'request:send', @model
  unfriend: confirmUnfriend
  invite: ->
    unless @group? then return _.error 'inviteUser err: group is missing'

    @group.inviteUser @model
    .catch behaviorsPlugin.Fail.call(@, 'invite user')

  acceptRequest: ->
    unless @group? then return _.error 'acceptRequest err: group is missing'

    @group.acceptRequest @model
    .catch behaviorsPlugin.Fail.call(@, 'accept user request')

  refuseRequest: ->
    unless @group? then return _.error 'refuseRequest err: group is missing'

    @group.refuseRequest @model
    .catch behaviorsPlugin.Fail.call(@, 'refuse user request')

module.exports = _.BasicPlugin events, handlers
