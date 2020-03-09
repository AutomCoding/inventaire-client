ListEl = Marionette.ItemView.extend
  tagName: 'li'
  template: require './templates/inventory_section_list_li'

  initialize: ->
    { @context, @group } = @options
    @lazyRender = _.LazyRender @
    if @model.get('hasItemsCount')
      @model.itemsCount = @model.waitForItemsCount.then @lazyRender

  serializeData: ->
    attrs = @model.serializeData()
    attrs.isGroup = attrs.type is 'group'
    attrs.isGroupAdmin = @isGroupAdmin()
    return attrs

  events:
    'click a': 'selectInventory'

  isGroupAdmin: -> @context is 'group' and @model.id in @group.allAdminsIds()

  selectInventory: (e)->
    if _.isOpenedOutside e then return
    type = @model.get('type') or 'user'
    if type is 'user' and @context is 'group' then type = 'member'
    app.vent.trigger 'inventory:select', type, @model
    e.preventDefault()

module.exports = Marionette.CollectionView.extend
  tagName: 'ul'
  childView: ListEl
  childViewOptions: ->
    context: @options.context
    group: @options.group
