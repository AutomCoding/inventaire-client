{ listingsData, transactionsData, getSelectorData } = require 'modules/inventory/lib/item_creation'
UpdateSelector = require 'modules/inventory/behaviors/update_selector'
error_ = require 'lib/error'
forms_ = require 'modules/general/lib/forms'
screen_ = require 'lib/screen'

CandidatesQueue = Marionette.CollectionView.extend
  tagName: 'ul'
  childView: require './candidate_row'
  childEvents:
    'selection:changed': -> @triggerMethod 'selection:changed'

ImportedItemsList = Marionette.CollectionView.extend
  tagName: 'ul'
  childView: require './imported_item_row'

module.exports = Marionette.LayoutView.extend
  className: 'import-queue'
  template: require './templates/import_queue'

  regions:
    candidatesQueue: '#candidatesQueue'
    itemsList: '#itemsList'

  ui:
    headCheckbox: 'thead input'
    validationElements: '.import, .progress'
    validateButton: '#validate'
    disabledValidateButton: '#disabledValidate'
    transaction: '#transaction'
    listing: '#listing'
    meter: '.meter'
    fraction: '.fraction'
    step2: '#step2'
    lastSteps: '#lastSteps'
    addedBooks: '#addedBooks'

  behaviors:
    UpdateSelector:
      behaviorClass: UpdateSelector
    AlertBox: {}
    Loading: {}

  serializeData: ->
    listings: listingsData()
    transactions: transactionsData()

  events:
    'change th.selected input': 'toggleAll'
    'click #selectAll': 'selectAll'
    'click #unselectAll': 'unselectAll'
    'click #emptyQueue': 'emptyQueue'
    'click #validate': 'validate'

  initialize: ->
    { @candidates } = @options
    @items = new Backbone.Collection
    @lazyUpdateSteps = _.debounce @updateSteps.bind(@), 50

  onShow: ->
    @candidatesQueue.show new CandidatesQueue { collection: @candidates }
    @itemsList.show new ImportedItemsList { collection: @items }
    @lazyUpdateSteps()

  selectAll: ->
    @candidates.setAllSelectedTo true
    @updateSteps()

  unselectAll: ->
    @candidates.setAllSelectedTo false
    @updateSteps()

  emptyQueue: ->
    @candidates.reset()

  childEvents:
    'selection:changed': 'lazyUpdateSteps'

  collectionEvents:
    'add': 'lazyUpdateSteps'

  updateSteps: ->
    if @candidates.selectionIsntEmpty()
      @ui.disabledValidateButton.addClass 'force-hidden'
      @ui.validateButton.removeClass 'force-hidden'
      @ui.lastSteps.removeClass 'force-hidden'
    else
      # Use 'force-hidden' as the class 'button' would otherwise overrides
      # the 'display' attribute
      @ui.validateButton.addClass 'force-hidden'
      @ui.disabledValidateButton.removeClass 'force-hidden'
      @ui.lastSteps.addClass 'force-hidden'

    if @candidates.length is 0
      @ui.step2.addClass 'force-hidden'
    else
      @ui.step2.removeClass 'force-hidden'

  validate: ->
    @toggleValidationElements()

    @selected = @candidates.getSelected()
    @total = @selected.length

    transaction = getSelectorData @, 'transaction'
    listing = getSelectorData @, 'listing'

    @chainedImport transaction, listing
    @planProgressUpdate()

  chainedImport: (transaction, listing)->
    if @selected.length is 0 then return @doneImporting()

    candidate = @selected.pop()
    candidate.createItem transaction, listing
    .catch (err)=>
      candidate.set 'errorMessage', err.message
      @failed or= []
      @failed.push candidate
      _.error err, 'chainedImport err'
      return
    .then (item)=>
      @candidates.remove candidate
      if item?
        @items.add item
        # Show the added books on the first successful import
        unless @_shownAddedBooks
          @_shownAddedBooks = true
          @setTimeout @showAddedBooks.bind(@), 1000
      # recursively trigger next import
      @chainedImport transaction, listing

    .catch error_.Complete('.validation')
    .catch forms_.catchAlert.bind(null, @)

  doneImporting: ->
    _.log 'done importing!'
    @stopProgressUpdate()
    @toggleValidationElements()
    @updateSteps()
    if @failed?.length > 0
      _.log @failed, 'failed candidates imports'
      @candidates.add @failed
      @failed = []
    # triggering events on the parent via childEvents
    @triggerMethod 'import:done'

  showAddedBooks: ->
    @ui.addedBooks.fadeIn()
    @setTimeout screen_.scrollTop.bind(null, @ui.addedBooks), 600

  toggleValidationElements: ->
    @ui.validationElements.toggleClass 'force-hidden'

  planProgressUpdate: ->
    # Using a recursive timeout instead of an interval
    # to avoid trying to update after a failed attempt
    # Typically occurring when the view as been destroyed
    @timeoutId = setTimeout @updateProgress.bind(@), 1000

  stopProgressUpdate: ->
    clearTimeout @timeoutId

  updateProgress: ->
    remaining = @selected.length
    added = @total - remaining
    percent = (added / @total) * 100
    @ui.meter.css 'width', "#{percent}%"
    @ui.fraction.text "#{added} / #{@total}"
    @planProgressUpdate()

  onDestroy: -> @stopProgressUpdate()
