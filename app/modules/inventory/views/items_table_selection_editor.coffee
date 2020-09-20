{ data: transactionsData } = require '../lib/transactions_data'
{ getShelvesByOwner } = require 'modules/shelves/lib/shelves'
ItemShelves = require './item_shelves'
Shelves = require 'modules/shelves/collections/shelves'

module.exports = Marionette.LayoutView.extend
  className: 'items-table-selection-editor'
  template: require './templates/items_table_selection_editor'
  events:
    'click .transaction-option': 'setTransaction'
    'click .listing-option': 'setListing'
    'click .delete': 'deleteItems'
    'click .done': -> app.execute 'modal:close'

  regions:
    'shelvesSelector': '.shelvesSelector'

  initialize: ->
    { @getSelectedModelsAndIds, @selectedIds } = @options

  serializeData: ->
    selectedIdsCount: @selectedIds.length
    transactions: transactionsData
    listings: app.user.listings()

  onShow: ->
    app.execute 'modal:open'
    @showShelves()

  setTransaction: (e)-> @updateItems e, 'transaction'

  setListing: (e)-> @updateItems e, 'listing'

  updateItems: (e, attribute)->
    value = e.currentTarget.id
    { selectedModelsAndIds } = @getSelectedModelsAndIds()
    app.request 'items:update', { items: selectedModelsAndIds, attribute, value }
    app.execute 'modal:close'

  deleteItems: ->
    if @selectedIds.length is 0 then return

    { selectedModelsAndIds, selectedModels, selectedIds } = @getSelectedModelsAndIds()

    app.request 'items:delete',
      items: selectedModelsAndIds
      next: @options.afterItemsDelete

  afterItemsDelete: ->
    app.execute 'modal:close'
    @options.afterItemsDelete()

  showShelves: ->
    getShelvesByOwner app.user.id
    .then @ifViewIsIntact('_showShelves')

  _showShelves: (shelves)->
    shelvesCollection = new Shelves shelves
    @shelvesSelector.show new ItemShelves
      collection: shelvesCollection
      itemsIds: @selectedIds
