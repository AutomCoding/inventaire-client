editableEntity = require './inv/editable_entity'
createEntities = require './create_entities'
properties = require './properties'
Entity = require '../models/entity'
{ buildPath } = require 'lib/location'

typeDefaultP31 =
  human: 'wd:Q5'
  work: 'wd:Q47461344'
  serie: 'wd:Q277759'
  edition: 'wd:Q3331189'
  publisher: 'wd:Q2085381'
  collection: 'wd:Q20655472'

propertiesShortlists =
  human: [ 'wdt:P1412' ]
  work: [ 'wdt:P50' ]
  serie: [ 'wdt:P50' ]
  edition: [ 'wdt:P629', 'wdt:P1476', 'wdt:P1680', 'wdt:P123', 'invp:P2', 'wdt:P407', 'wdt:P577' ]
  publisher: [ 'wdt:P856', 'wdt:P112', 'wdt:P571', 'wdt:P576' ]
  collection: [ 'wdt:P1476', 'wdt:P123', 'wdt:P98', 'wdt:P856' ]

module.exports =
  create: (options)->
    { type, label, claims, next, relation } = options

    # TODO: allow to select specific type at creation
    defaultP31 = typeDefaultP31[type]
    unless defaultP31?
      throw new Error "unknown type: #{type}"

    claims or= {}
    claims['wdt:P31'] = [ defaultP31 ]

    labels = {}
    if label?
      # use the label we got as a label suggestion
      labels[app.user.lang] = label

    model = new Backbone.NestedModel { type, labels, claims }
    Entity::setFavoriteLabel.call model, model.toJSON()

    _.extend model,
      type: type
      creating: true
      # The property that links this entity to another entity being created
      relation: relation
      propertiesShortlist: getPropertiesShortlist type, claims
      setPropertyValue: editableEntity.setPropertyValue.bind model
      savePropertyValue: Promise.getResolved
      setLabel: editableEntity.setLabel.bind model
      resetLabels: (lang, value)->
        @set 'labels', {}
        @setLabel lang, value
      # Required by editableEntity.setPropertyValue
      invalidateRelationsCache: _.noop
      saveLabel: Promise.getResolved
      create: ->
        createEntities.create
          labels: @get 'labels'
          claims: @get 'claims'
      fetchSubEntities: Entity::fetchSubEntities
      fetchSubEntitiesUris: Entity::fetchSubEntitiesUris

      # Methods required by app.navigateFromModel
      updateMetadata: -> { title: label or _.I18n('new entity') }
      getRefresh: _.identity

    # Attributes required by app.navigateFromModel
    model.set 'edit', buildPath('/entity/new', options)

    Entity::typeSpecificInit.call model

    return model

  allowlistedTypes: Object.keys typeDefaultP31

getPropertiesShortlist = (type, claims)->
  typeShortlist = propertiesShortlists[type]
  unless typeShortlist? then return null

  claimsProperties = Object.keys(claims).filter nonFixedEditor
  propertiesShortlist = propertiesShortlists[type].concat claimsProperties
  # If a serie was passed in the claims, invite to add an ordinal
  if 'wdt:P179' in claimsProperties then propertiesShortlist.push 'wdt:P1545'

  return propertiesShortlist

nonFixedEditor = (prop)->
  # Testing properties[prop] existance as some properties don't
  # have an editor. Ex: wdt:P31
  editorType = properties[prop]?.editorType
  unless editorType then return false

  # Filter-out fixed editor: 'fixed-entity', 'fixed-string'
  if editorType.split('-')[0] is 'fixed' then return false

  return true
