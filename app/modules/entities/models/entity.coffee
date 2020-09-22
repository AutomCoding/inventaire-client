# One unique Entity model to rule them all
# but with specific initializers:
# - By source:
#   - Wikidata entities have specific initializers related to Wikimedia sitelinks
# - By type: see specialInitializersByType

isbn_ = require 'lib/isbn'
entities_ = require '../lib/entities'
initializeWikidataEntity = require '../lib/wikidata/init_entity'
initializeInvEntity = require '../lib/inv/init_entity'
editableEntity = require '../lib/inv/editable_entity'
getBestLangValue = require 'modules/entities/lib/get_best_lang_value'
getOriginalLang = require 'modules/entities/lib/get_original_lang'
error_ = require 'lib/error'
Filterable = require 'modules/general/models/filterable'

specialInitializersByType =
  human: require '../lib/types/author'
  serie: require '../lib/types/serie'
  work: require '../lib/types/work'
  edition: require '../lib/types/edition'
  publisher: require '../lib/types/publisher'
  collection: require '../lib/types/collection'

editableTypes = Object.keys specialInitializersByType

placeholdersTypes = [ 'meta', 'missing' ]

module.exports = Filterable.extend
  initialize: (attrs, options)->
    @refresh = options?.refresh
    @type = attrs.type or options.defaultType

    if @type?
      @pluralizedType = @type + 's'

    if @type in placeholdersTypes
      # Set placeholder attributes so that the logic hereafter doesn't crash
      _.extend attrs, placeholderAttributes
      @set placeholderAttributes

    @setCommonAttributes attrs
    # Keep label updated
    @on 'change:labels', => @setFavoriteLabel @toJSON()

    # List of promises created from specialized initializers
    # to wait for before triggering @executeMetadataUpdate (see below)
    @_dataPromises = []

    if @wikidataId then initializeWikidataEntity.call @, attrs
    else initializeInvEntity.call @, attrs

    if @type in editableTypes
      pathname = @get 'pathname'
      @set
        edit: "#{pathname}/edit"
        cleanup: "#{pathname}/cleanup"
        history: "#{pathname}/history"

    # If the entity isn't of any known type, it was probably fetched
    # for its label, there is thus no need to go further on initialization
    # as what follows is specific to core entities types
    # Or, it was fetched for its relation with an other entity but misses
    # the proper P31 data to display correctly. Then, when fetching the entity
    # a defaultType should be passed as option.
    # For instance, parts of a serie will default have a defaultType='work'
    unless @type
      # Placeholder
      @waitForData = Promise.resolve()
      return

    if @get('edit')? then _.extend @, editableEntity

    # An object to store only the ids of such a relationship
    # ex: this entity is a P50 of entities Q...
    # /!\ Legacy: to be harmonized/merged with @subentities
    @set 'reverseClaims', {}

    @typeSpecificInit()

    if @_dataPromises.length is 0 then @waitForData = Promise.resolve()
    else @waitForData = Promise.all @_dataPromises

  typeSpecificInit: ->
    specialInitializer = specialInitializersByType[@type]
    if specialInitializer? then specialInitializer.call @

  setCommonAttributes: (attrs)->
    unless attrs.claims?
      error_.report 'entity without claims', { attrs }
      attrs.claims = {}

    { uri, type } = attrs
    [ prefix, id ] = uri.split ':'

    if prefix is 'wd' then @wikidataId = id

    isbn13h = attrs.claims['wdt:P212']?[0]
    # Using de-hyphenated ISBNs for URIs
    if isbn13h? then @isbn = isbn_.normalizeIsbn isbn13h

    if prefix isnt 'inv' then @setInvAltUri()

    type ?= 'subject'
    @defaultClaimProperty = defaultClaimPropertyByType[type]

    if @defaultClaimProperty?
      pathname = "/entity/#{@defaultClaimProperty}-#{uri}"
    else
      pathname = "/entity/#{uri}"

    @set { type, prefix, pathname }
    @setFavoriteLabel attrs

  # Not naming it 'setLabel' as it collides with editable_entity own 'setLabel'
  setFavoriteLabel: (attrs)->
    @originalLang = getOriginalLang attrs.claims
    label = getBestLangValue(app.user.lang, @originalLang, attrs.labels).value
    @set 'label', label

  setInvAltUri: ->
    invId = @get '_id'
    if invId? then @set 'altUri', "inv:#{invId}"

  fetchSubEntities: (refresh)->
    refresh = @getRefresh refresh
    if not refresh and @waitForSubentities? then return @waitForSubentities

    unless @subentitiesName?
      @waitForSubentities = Promise.resolve()
      return @waitForSubentities

    collection = @[@subentitiesName] = new Backbone.Collection

    # A draft entity can't already have subentities
    if @creating then return @waitForSubentities = Promise.resolve()

    uri = @get 'uri'
    prop = @childrenClaimProperty

    @waitForSubentities = entities_.getReverseClaims prop, uri, refresh
      .tap @setSubEntitiesUris.bind(@)
      .then (uris)-> app.request 'get:entities:models', { uris, refresh }
      .then @beforeSubEntitiesAdd.bind(@)
      .then collection.add.bind(collection)
      .tap @afterSubEntitiesAdd.bind(@)

  # Override in sub-types
  beforeSubEntitiesAdd: _.identity
  afterSubEntitiesAdd: _.noop

  setSubEntitiesUris: (uris)->
    @set 'subEntitiesUris', uris
    if @subEntitiesInverseProperty then @set "claims.#{@subEntitiesInverseProperty}", uris
    # The list of all uris that describe an entity that is this work or a subentity,
    # that is, an edition of this work
    @set 'allUris', [ @get('uri') ].concat(uris)

  # To be called by a view onShow:
  # updates the document with the entities data
  updateMetadata: ->
    @waitForData
    .then @executeMetadataUpdate.bind(@)
    .catch _.Error('updateMetadata err')

  executeMetadataUpdate: ->
    return Promise.props
      title: @buildTitle()
      description: @findBestDescription()?[0..500]
      image: @getImageSrcAsync()
      url: @get 'pathname'
      smallCardType: true

  findBestDescription: ->
    # So far, only Wikidata entities get extracts
    [ extract, description ] = @gets 'extract', 'description'
    # Dont use an extract too short as it will be
    # more of it's wikipedia source url than a description
    if extract?.length > 300 then return extract
    else return description or extract

  # Override in with type-specific methods
  buildTitle: ->
    label = @get 'label'
    type = @get 'type'
    P31 = @get 'claims.wdt:P31.0'
    typeLabel = _.I18n(typesString[P31] or type)
    return "#{label} - #{typeLabel}"

  getImageAsync: -> Promise.resolve @get('image')
  getImageSrcAsync: ->
    @getImageAsync()
    # Let app/lib/metadata/apply_transformers format the URL with app.API.img
    .then (imageObj)-> imageObj?.url

  getRefresh: (refresh)->
    refresh = refresh or @refresh or @graphChanged
    # No need to force refresh until next graph change
    @graphChanged = false
    return refresh

  matchable: ->
    { lang } = app.user
    userLangAliases = @get("aliases.#{lang}") or []
    return [ @get('label') ].concat userLangAliases

  # Overriden by modules/entities/lib/wikidata/init_entity.coffee
  # for Wikidata entities
  getWikipediaExtract: -> Promise.resolve()

placeholderAttributes =
  labels: {}
  aliases: {}
  descriptions: {}
  claims: {}
  sitelinks: {}

defaultClaimPropertyByType =
  movement: 'wdt:P135'
  genre: 'wdt:P136'
  subject: 'wdt:P921'

typesString =
  'wd:Q5': 'author'
  # works
  'wd:Q571': 'book'
  'wd:Q47461344': 'book'
  'wd:Q1004': 'comic book'
  'wd:Q8274': 'manga'
  'wd:Q49084': 'short story'
  # series
  'wd:Q277759': 'book series'
  'wd:Q14406742': 'comic book series'
  'wd:Q21198342': 'manga series'
