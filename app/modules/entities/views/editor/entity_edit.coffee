TitleEditor = require './title_editor'
PropertiesEditor = require './properties_editor'
propertiesCollection = require '../../lib/editor/properties_collection'
AdminSection = require './admin_section'
forms_ = require 'modules/general/lib/forms'
error_ = require 'lib/error'

module.exports = Marionette.LayoutView.extend
  id: 'entityEdit'
  template: require './templates/entity_edit'
  behaviors:
    PreventDefault: {}
    AlertBox: {}

  regions:
    title: '.title'
    claims: '.claims'
    admin: '.admin'

  ui:
    navigationButtons: '.navigationButtons'

  initialize: ->
    @creationMode = @model.creating
    @requiresLabel = @model.type isnt 'edition'
    @canBeAddedToInventory = @model.type in inventoryTypes
    @showAdminSection = app.user.isAdmin and not @creationMode

    { waitForSubentities } = @model
    # Some entity type don't automatically fetch their subentities
    # even for the editor, as sub entites are displayed on the entities' page
    # already
    waitForSubentities or= _.preq.resolved

    @waitForPropCollection = waitForSubentities
      .then @initPropertiesCollections.bind(@)

    @navigationButtonsDisabled = false

  initPropertiesCollections: -> @properties = propertiesCollection @model

  onShow: ->
    if @requiresLabel
      @title.show new TitleEditor { @model }

    if @showAdminSection
      @admin.show new AdminSection { @model }

    @waitForPropCollection
    .then @showPropertiesEditor.bind(@)

    @listenTo @model, 'change', @updateNavigationButtons.bind(@)
    @updateNavigationButtons()

  showPropertiesEditor: ->
    @claims.show new PropertiesEditor
      collection: @properties
      propertiesShortlist: @model.propertiesShortlist

  serializeData: ->
    attrs = @model.toJSON()
    attrs.creationMode = @creationMode
    typePossessive = possessives[attrs.type]
    attrs.createAndShowLabel = "create and go to the #{typePossessive} page"
    attrs.returnLabel = "return to the #{typePossessive} page"
    attrs.creating = @model.creating
    attrs.canCancel = @canCancel()
    # Do not show the signal data error button in creation mode
    # as it wouldn't make sense
    attrs.signalDataErrorButton = not @creationMode
    # Used when item_show attempts to 'preciseEdition' with a new edition
    attrs.itemToUpdate = @itemToUpdate
    attrs.canBeAddedToInventory = @canBeAddedToInventory
    return attrs

  events:
    'click .entity-edit-cancel': 'cancel'
    'click .createAndShowEntity': 'createAndShowEntity'
    'click .createAndAddEntity': 'createAndAddEntity'
    'click .createAndUpdateItem': 'createAndUpdateItem'
    'click #signalDataError': 'signalDataError'

  canCancel: ->
    # In the case of an entity being created, showing the entity page would fail
    unless @model.creating then return true
    # Don't display a cancel button if we don't know whre to redirect
    return Backbone.history.last.length > 0

  cancel: ->
    fallback = => app.execute 'show:entity:from:model', @model
    app.execute 'history:back', { fallback }

  createAndShowEntity: ->
    @_createAndAction app.Execute('show:entity:from:model')

  createAndAddEntity: ->
    @_createAndAction app.Execute('show:entity:add:from:model')

  createAndUpdateItem: ->
    { itemToUpdate } = @
    if itemToUpdate instanceof Backbone.Model
      @_createAndUpdateItem itemToUpdate
    else
      # If the view was loaded from the URL, @itemToUpdate will be just
      # the URL persisted attributes instead of a model object
      app.request 'get:item:model', @itemToUpdate._id
      .then @_createAndUpdateItem.bind(@)

  _createAndUpdateItem: (item)->
    action = (entity)-> app.request 'item:update:entity', item, entity
    @_createAndAction action

  _createAndAction: (action)->
    @beforeCreate()
    .then @model.create.bind(@model)
    .then action
    .catch error_.Complete('.meta', false)
    .catch forms_.catchAlert.bind(null, @)

  # Override in sub views
  beforeCreate: -> _.preq.resolved

  signalDataError: (e)->
    uri = @model.get 'uri'
    subject = _.I18n  'data error'
    app.execute 'show:feedback:menu',
      subject: "[#{uri}][#{subject}] "
      event: e

  # Hiding navigation buttons when a label is required but no label is set yet
  # to invite the user to edit and save the label, or cancel.
  updateNavigationButtons: ->
    labelsCount = _.values(@model.get('labels')).length
    if @requiresLabel and labelsCount is 0
      unless @navigationButtonsDisabled
        @ui.navigationButtons.hide()
        @navigationButtonsDisabled = true
    else
      if @navigationButtonsDisabled
        @ui.navigationButtons.fadeIn()
        @navigationButtonsDisabled = false

possessives =
  work: "book's"
  edition: "edition's"
  serie: "series'"
  human: "author's"

inventoryTypes = [ 'work', 'edition' ]
