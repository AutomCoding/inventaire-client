# A set of functions to display a list of suggestions and the the view be informed of
# the selected suggestion via onAutoCompleteSelect and onAutoCompleteUnselect hooks

# Forked from: https://github.com/KyleNeedham/autocomplete/blob/master/src/autocomplete.behavior.coffee

getActionKey = require 'lib/get_action_key'
Suggestions = require 'modules/entities/collections/suggestions'
AutocompleteSuggestions = require '../autocomplete_suggestions'
properties = require 'modules/entities/lib/properties'
batchLength = 10
notSearchableProps = [ 'wdt:P31' ]
{ addDefaultSuggestionsUris, addNextDefaultSuggestionsBatch, showDefaultSuggestions } = require './suggestions/default_suggestions'
{ search, loadMoreFromSearch } = require './suggestions/search_suggestions'

module.exports =
  onRender: ->
    unless @suggestions? then initializeAutocomplete.call @
    @suggestionsRegion.show new AutocompleteSuggestions { collection: @suggestions }
    addDefaultSuggestionsUris.call @

  onKeyDown: (e)->
    key = getActionKey e
    # only addressing 'tab' as it isn't caught by the keyup event
    if key is 'tab'
      # In the case the dropdown was shown and a value was selected
      # @fillQuery will have been triggered, the input filled
      # and the selected suggestion kept at end: we can let the event
      # propagate to move to the next input
      @hideDropdown()

  onKeyUp: (e)->
    e.preventDefault()
    e.stopPropagation()

    value = @ui.input.val()
    actionKey = getActionKey e

    updateOnKey.call @, value, actionKey
    @_lastValue = value

  showDropdown: ->
    @suggestionsRegion.$el.show()

  hideDropdown: ->
    @suggestionsRegion.$el.hide()
    @ui.input.focus()

  showLoadingSpinner: (toggleResults = true)->
    @suggestionsRegion.currentView.showLoadingSpinner()
    if toggleResults then @$el.find('.results').hide()

  stopLoadingSpinner: (toggleResults = true)->
    @suggestionsRegion.currentView.stopLoadingSpinner()
    if toggleResults then @$el.find('.results').show()

initializeAutocomplete = ->
  property = @options.model.get 'property'
  { @searchType } = properties[property]
  @suggestions = new Suggestions [], { property }
  @lazySearch = _.debounce search.bind(@), 400

  @listenTo @suggestions, 'selected:value', completeQuery.bind(@)
  @listenTo @suggestions, 'highlight', fillQuery.bind(@)
  @listenTo @suggestions, 'error', showAlertBox.bind(@)
  @listenTo @suggestions, 'load:more', loadMore.bind(@)

# Complete the query using the selected suggestion.
completeQuery = (suggestion)->
  fillQuery.call @, suggestion
  @hideDropdown()

# Complete the query using the highlighted or the clicked suggestion.
fillQuery = (suggestion)->
  @ui.input.val suggestion.get('label')
  @onAutoCompleteSelect suggestion

loadMore = ->
  if @_showingDefaultSuggestions then addNextDefaultSuggestionsBatch.call @, false
  else loadMoreFromSearch.call @

showAlertBox = (err)->
  @$el.trigger 'alert', { message: err.message }

updateOnKey = (value, actionKey)->
  if actionKey?
    actionMade = keyAction.call @, actionKey
    if actionMade isnt false then return

  if value.length is 0
    showDefaultSuggestions.call @
    @_showingDefaultSuggestions = true
  else if value isnt @_lastValue
    refreshSuggestions.call @, value
    @_showingDefaultSuggestions = false

refreshSuggestions = (value)->
  @showDropdown()
  if @property in notSearchableProps
    matchedSuggestions = filterSuggestions(@_defaultSuggestions, value)
    if matchedSuggestions? and matchedSuggestions.length > 0
      @suggestions.reset matchedSuggestions
  else
    @lazySearch value

filterSuggestions = (suggestions, value)->
  suggestions.filter (entity)-> entity.matches(value)

keyAction = (actionKey)->
  # actions happening in any case
  switch actionKey
    when 'esc'
      @hideDropdown()
      return true

  # actions conditional to suggestions state
  unless @suggestions.isEmpty()
    switch actionKey
      when 'enter'
        @suggestions.trigger 'select:from:key'
        return true
      when 'down'
        @showDropdown()
        @suggestions.trigger 'highlight:next'
        return true
      when 'up'
        @showDropdown()
        @suggestions.trigger 'highlight:previous'
        return true
      # when 'home' then @suggestions.trigger 'highlight:first'
      # when 'end' then @suggestions.trigger 'highlight:last'

  return false
