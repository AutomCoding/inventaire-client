# TODO:
# - hint to input ISBNs directly, maybe in the alternatives sections
# - add 'help': indexed wiki.inventaire.io entries to give results
#   to searches such as 'FAQ' or 'help creating group'
# - add 'place': search Wikidata for entities with coordinates (wdt:P625)
#   and display a layout with users & groups nearby, as well as books with
#   narrative location (wdt:P840), or authors born (wdt:P19)
#   or dead (wdt:P20) nearby

Results = Backbone.Collection.extend { model: require('../models/result') }
wikidataSearch = require('modules/entities/lib/search/wikidata_search')(false)
findUri = require '../lib/find_uri'
error_ = require 'lib/error'
{ looksLikeAnIsbn, normalizeIsbn } = require 'lib/isbn'
screen_ = require 'lib/screen'
searchBatchLength = 10
searchCount = 0

module.exports = Marionette.CompositeView.extend
  id: 'live-search'
  template: require './templates/live_search'
  childViewContainer: 'ul.results'
  childView: require './result'
  emptyView: require './no_result'

  initialize: ->
    @collection = new Results
    @_lazySearch = _.debounce @search.bind(@), 500
    { section: @selectedSectionName } = @options
    @_searchOffset = 0

  ui:
    all: '#section-all'
    entitiesSections: '.entitiesSections'
    socialSections: '.socialSections'
    resultsWrapper: '.resultsWrapper'
    results: 'ul.results'
    alternatives: '.alternatives'
    shortcuts: '.shortcuts'
    loader: '.loaderWrapper'

  serializeData: ->
    entitiesSections = sectionsData().entitiesSections
    socialSections = sectionsData().socialSections
    unless entitiesSections[@selectedSectionName]? or socialSections[@selectedSectionName]?
      _.warn { @selectedSectionName }, 'unknown search section'
      @selectedSectionName = 'book'
    entitiesSections[@selectedSectionName].selected = true
    return { socialSections, entitiesSections }

  events:
    'click .searchSection': 'updateSections'
    'click .createEntity': 'showEntityCreate'

  onShow: ->
    # Doesn't work if set in events for some reason
    @ui.resultsWrapper.on 'scroll', @onResultsScroll.bind(@)

  onSpecialKey: (key)->
    switch key
      when 'up' then @highlightPrevious()
      when 'down' then @highlightNext()
      when 'enter' then @showCurrentlyHighlightedResult()
      when 'pageup' then @selectPrevSection()
      when 'pagedown' then @selectNextSection()
      else return

  updateSections: (e)-> @selectTypeFromTarget $(e.currentTarget)

  selectPrevSection: -> @selectByPosition 'prev', 'last'
  selectNextSection: -> @selectByPosition 'next', 'first'
  selectByPosition: (relation, fallback)->
    $target = @$el.find('.selected')[relation]()
    if $target.length is 0 then $target = @$el.find('.sections a')[fallback]()
    @selectTypeFromTarget $target

  selectTypeFromTarget: ($target)->
    { id } = $target[0]
    name = getTypeFromId id
    @selectSectionAndSearch name

  selectSectionAndSearch: (name)->
    if @isSectionSelected name
      @unselectSection name
    else
      if isSocialSection name then @updateSocialSections name
      if isEntitiesSection name then @updateEntitiesSections name

    @_searchOffset = 0
    @_lastType = name
    # Refresh the search with the new sections
    if @_lastSearch? and @_lastSearch isnt '' then @lazySearch @_lastSearch

    @updateAlternatives name

  unselectSection: (name) ->
    if isSocialSection name
      @ui.socialSections.find("#section-#{name}").removeClass 'selected'
    if isEntitiesSection name
      @ui.entitiesSections.find("#section-#{name}").removeClass('selected')

  updateEntitiesSections: (name) ->
    if isSocialSection @_lastType

      @ui.socialSections.find(".socialSection").removeClass 'selected'
    # unselect all selected section to have a search dedicated to subjects only
    if name is 'subject'
      @ui.entitiesSections.find(".entitiesSection").removeClass 'selected'
    else
      @ui.entitiesSections.find("#section-subject").removeClass 'selected'
    @ui.entitiesSections.find("#section-#{name}").addClass 'selected'
    # @entitiesSection = (child)-> child.get('typeAlias') is name

  updateSocialSections: (name) ->
    # needs to unselect the default 'book' section
    if !@_lastType or isEntitiesSection @_lastType
      @ui.entitiesSections.find(".entitiesSection").removeClass 'selected'
    @ui.socialSections.find("#section-#{name}").addClass 'selected'
    # @socialSection = (child)-> child.get('typeAlias') is name

  updateAlternatives: (search)->
    if @_lastType in sectionsWithAlternatives then @showAlternatives(search)
    else @hideAlternatives()

  search: (search)->
    search = search?.trim()
    @_lastSearch = search
    @_lastSearchId = ++searchCount
    @_searchOffset = 0

    unless _.isNonEmptyString search then return @hideAlternatives()

    uri = findUri search
    if uri? then return @getResultFromUri uri, @_lastSearchId, @_lastSearch

    @_search search
    .then @resetResults.bind(@, @_lastSearchId)

    @_waitingForAlternatives = true
    @setTimeout @updateAlternatives.bind(@, search), 2000

  _search: (search)->
    types = @getTypes()
    # Subjects aren't indexed in the server ElasticSearch
    # as it's not a subset of Wikidata anymore: pretty much anything
    # on Wikidata can be considered a subject
    if types.includes 'subjects'
      wikidataSearch search, searchBatchLength, @_searchOffset
      .map formatSubject
    else
      # Increasing search limit instead of offset, as search pages aren't stable:
      # results popularity might have change the results order between two requests,
      # thus the need to re-fetch from offset 0 but increasing the page length, and adding only
      # the results that weren't returned in the previous query, whatever there place
      # in the newly returned results
      searchLimit = searchBatchLength + @_searchOffset
      _.preq.get app.API.search(types, search, searchLimit)
      .get 'results'

  lazySearch: (search)->
    if search.length > 0 then @showLoadingSpinner()
    else @stopLoadingSpinner()
    # Hide previous results to limit confusion and scroll up
    @resetResults()
    @_lazySearch search

  showAlternatives: (search)->
    unless _.isNonEmptyString search then return
    unless search is @_lastSearch then return
    unless @_waitingForAlternatives then return

    @ui.alternatives.addClass 'shown'
    @_waitingForAlternatives = false

  hideAlternatives: ->
    @_waitingForAlternatives = false
    @ui.alternatives.removeClass 'shown'

  showShortcuts: -> @ui.shortcuts.addClass 'shown'

  getResultFromUri: (uri, searchId, rawSearch)->
    _.log uri, 'uri found'
    @showLoadingSpinner()

    app.request 'get:entity:model', uri
    .then (entity)=> @resetResults searchId, [ formatEntity(entity) ]
    .catch (err)=>
      if err.message is 'entity_not_found'
        @_waitingForAlternatives = true
        @showAlternatives rawSearch
      else
        throw err
    .finally @stopLoadingSpinner.bind(@)

  showLoadingSpinner: ->
    @ui.loader.html '<div class="small-loader"></div>'
    @$el.removeClass 'no-results'

  stopLoadingSpinner: -> @ui.loader.html ''

  getTypes: ->
    names = @getSelectedSectionsNames()
    return _.map(names, getSectionType)

  resetResults: (searchId, results)->
    # Ignore results from any search that isn't the latest search
    if searchId? and searchId isnt @_lastSearchId then return

    @resetHighlightIndex()

    if results?
      @stopLoadingSpinner()
      @_lastResultsLength = results.length

      # Track TypeErrors where Result model 'initialize' crashes
      try @collection.reset results
      catch err
        err.context ?= {}
        err.context.results = results
        throw err

    else
      @collection.reset()

    if results? and results.length is 0
      @$el.addClass 'no-results'
    else
      @$el.removeClass 'no-results'
      @setTimeout @showShortcuts.bind(@), 1000

  highlightNext: -> @highlightIndexChange 1
  highlightPrevious: -> @highlightIndexChange -1
  highlightIndexChange: (incrementor)->
    @_currentHighlightIndex ?= -1
    newIndex = @_currentHighlightIndex + incrementor
    previousView = @children.findByIndex @_currentHighlightIndex
    view = @children.findByIndex newIndex
    if view?
      previousView?.unhighlight()
      view.highlight()
      @_currentHighlightIndex = newIndex

      screen_.innerScrollTop @ui.results, view?.$el

  showCurrentlyHighlightedResult: ->
    hilightedView = @children.findByIndex @_currentHighlightIndex
    if hilightedView then hilightedView.showResult()

  resetHighlightIndex: ->
    @$el.find('.highlight').removeClass 'highlight'
    @_currentHighlightIndex = -1

  showEntityCreate: ->
    @triggerMethod 'hide:live:search'
    if looksLikeAnIsbn @_lastSearch
      # If the edition entity for this ISBN really doesn't exist
      # it will redirect to the ISBN edition creation form
      app.execute 'show:entity', @_lastSearch
    else
      section = @_lastType or @selectedSectionName
      type = sectionToTypes[section]
      app.execute 'show:entity:create', { label: @_lastSearch, type, allowToChangeType: true }

  onResultsScroll: (e)->
    visibleHeight = @ui.resultsWrapper.height()
    { scrollHeight, scrollTop } = e.currentTarget
    scrollBottom = scrollTop + visibleHeight
    if scrollBottom is scrollHeight then @loadMore()

  loadMore: ->
    # Do not try to fetch more results if the last batch was incomplete
    if @_lastResultsLength < searchBatchLength then return @stopLoadingSpinner()

    @showLoadingSpinner()
    @_searchOffset += searchBatchLength
    @_search @_lastSearch
    .then @addNewResults.bind(@)

  addNewResults: (results)->
    currentResultsUri = @collection.map (model)-> model.get('uri')
    newResults = results.filter (result)-> result.uri not in currentResultsUri
    @_lastResultsLength = newResults.length
    @collection.add newResults

  isSectionSelected: (name)->
    names = @getSelectedSectionsNames()
    names.includes name

  getSelectedSectionsNames: ()->
    selectedElements = $.find('.selected')
    getTypesFromIds _.map(selectedElements, _.identity('id'))

sectionToTypes =
  book: 'works'
  author: 'humans'
  serie: 'series'
  collection: 'collections'
  publisher: 'publishers'
  subject: 'subjects'
  user: 'users'
  group: 'groups'

sectionsWithAlternatives = [ 'book', 'author', 'serie', 'collection', 'publisher' ]

isEntitiesSection = (name)-> sectionsData().entitiesSections[name]?

isSocialSection = (name)-> sectionsData().socialSections[name]?

getTypesFromIds = (ids)-> _.map(ids, getTypeFromId)

getTypeFromId = (id)-> id.replace 'section-', ''

getSectionType = (name)-> sectionToTypes[name]

# Pre-formatting is required to set the type
# Taking the opportunity to omit all non-required data
formatSubject = (result)->
  id: result.id
  label: result.label
  description: result.description
  uri: "wd:#{result.id}"
  type: 'subjects'

formatEntity = (entity)->
  unless entity?.toJSON?
    error_.report 'cant format invalid entity', { entity }
    return

  data = entity.toJSON()
  data.image = data.image?.url
  # Return a model to prevent having it re-formatted
  # as a Result model, which works from a result object, not an entity
  return new Backbone.Model data

sectionsData = ->
  entitiesSections:
    book: { label: 'book' }
    author: { label: 'author' }
    serie: { label: 'series_singular' }
    publisher: { label: 'publisher' }
    collection: { label: 'collection' }
    subject: { label: 'subject' }
  socialSections:
    user: { label: 'user' }
    group: { label: 'group' }
