RequestItemModal = require './request_item_modal'
itemUpdaters = require '../plugins/item_updaters'

module.exports = ItemLi = Backbone.Marionette.ItemView.extend
  tagName: 'figure'
  className: ->
    @uniqueSelector = ".#{@cid}"
    "itemContainer #{@cid}"
  template: require './templates/item_figure'
  behaviors:
    PreventDefault: {}
    ConfirmationModal: {}

  initialize: ->
    @initPlugins()
    @lazyRender = _.debounce @render.bind(@), 400
    @listenTo @model, 'change', @lazyRender
    @listenTo @model, 'entity:ready', @lazyRender

  initPlugins: -> itemUpdaters.call(@)

  onRender: ->
    app.execute('foundation:reload')
    app.request('qLabel:update')

  events:
    'click .edit': 'itemEdit'
    'click a.itemShow': 'itemShow'
    'click a.detailsToggleWrap': -> @toggleWrap('details')
    'click a.notesToggleWrap': -> @toggleWrap('notes')

  serializeData: ->
    attrs = @model.serializeData()
    attrs.entityData = @model.entityModel?.toJSON()
    attrs.wrap = @wrapData(attrs)
    attrs.date = {date: attrs.created}
    return attrs

  wrapData: (attrs)->
    details:
      wrap: attrs.details?.length > 120
      nameBase: 'details'
    notes:
      wrap: attrs.notes?.length > 120
      nameBase: 'notes'

  itemEdit: -> app.execute 'show:item:form:edition', @model

  itemShow: (e)->
    unless _.isOpenedOutside(e)
      app.execute 'show:item:show:from:model', @model

  itemDestroy: ->
    app.request 'item:destroy',
      model: @model
      selector: @uniqueSelector
      next: -> console.log 'item deleted'

  showUser: (e)->
    unless _.isOpenedOutside(e)
      app.execute 'show:user', @model.username

  toggleWrap: (nameBase)->
    @$el.find("span.#{nameBase}").toggleClass('wrapped')
    @$el.find("a.#{nameBase}ToggleWrap").find('.fa').toggle()
    @trigger 'resize'

  requestItem: ->
    app.layout.modal.show new RequestItemModal {model: @model}
