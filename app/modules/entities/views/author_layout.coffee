TypedEntityLayout = require './typed_entity_layout'
{ startLoading } = require 'modules/general/plugins/behaviors'
EntitiesList = require './entities_list'
screen_ = require 'lib/screen'

module.exports = TypedEntityLayout.extend
  template: require './templates/author_layout'
  Infobox: require './author_infobox'
  className: ->
    # Default to wrapped mode in non standalone mode
    secondClass = ''
    if @options.standalone then secondClass = 'standalone'
    else if not @options.noAuthorWrap then secondClass = 'wrapped'
    prefix = @model.get 'prefix'
    return "authorLayout #{secondClass} entity-prefix-#{prefix}"

  attributes: ->
    # Used by deduplicate_layout
    'data-uri': @model.get('uri')

  behaviors:
    Loading: {}

  regions:
    infoboxRegion: '.authorInfobox'
    seriesRegion: '.series'
    worksRegion: '.works'
    articlesRegion: '.articles'
    mergeSuggestionsRegion: '.mergeSuggestions'

  initialize: ->
    TypedEntityLayout::initialize.call @
    # Trigger fetchWorks only once the author is in view
    @$el.once 'inview', @fetchWorks.bind(@)

  events:
    'click .unwrap': 'unwrap'

  fetchWorks: ->
    @worksShouldBeShown = true
    # make sure refresh is a Boolean and not an object incidently passed
    refresh = @options.refresh is true

    @model.initAuthorWorks refresh
    .then @ifViewIsIntact('showWorks')
    .catch _.Error('author_layout fetchWorks err')

  onRender: ->
    TypedEntityLayout::onRender.call @
    if @worksShouldBeShown then @showWorks()

  showWorks: ->
    startLoading.call @, '.works'

    @model.waitForWorks
    .then @_showWorks.bind(@)

  _showWorks: ->
    { works, series, articles } = @model.works
    total = works.totalLength + series.totalLength + articles.totalLength

    # Always starting wrapped on small screens
    if not screen_.isSmall(600) and total > 0 then @unwrap()

    initialWorksListLength = if @standalone then 10 else 5

    @showWorkCollection 'works', initialWorksListLength

    seriesCount = @model.works.series.totalLength
    if seriesCount > 0 or @standalone
      @showWorkCollection 'series', initialWorksListLength
      # If the author has no series, move the series block down
      if seriesCount is 0 then @seriesRegion.$el.css 'order', 2

    if @model.works.articles.totalLength > 0
      @showWorkCollection 'articles'

  unwrap: -> @$el.removeClass 'wrapped'

  showWorkCollection: (type, initialLength)->
    @["#{type}Region"].show new EntitiesList
      parentModel: @model
      collection: @model.works[type]
      title: type
      type: dropThePlural type
      initialLength: initialLength
      showActions: @options.showActions
      wrapWorks: @options.wrapWorks
      addButtonLabel: addButtonLabelPerType[type]

addButtonLabelPerType =
  works: 'add a work from this author'
  series: 'add a serie from this author'

dropThePlural = (type)-> type.replace /s$/, ''
