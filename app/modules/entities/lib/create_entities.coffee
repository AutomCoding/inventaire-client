InvEntity = require '../models/inv_entity'
error_ = require 'lib/error'
books_ = require 'lib/books'

createAuthor = (name, lang)->
  _.types arguments, 'strings...'
  labels = {}
  labels[lang] = name
  # instance of (P31) -> human (Q5)
  claims = { 'wdt:P31': ['wd:Q5'] }
  return createEntity labels, claims

createAuthors = (authorsNames, lang)->
  _.types arguments, ['array|null', 'string']
  if authorsNames?.length > 0
    return Promise.all authorsNames.map (name)-> createAuthor name, lang
  else
    return _.preq.resolve []

createBook = (title, authors, authorsNames, lang)->
  _.types arguments, ['string', 'array', 'array|null', 'string']

  labels = {}
  labels[lang] = title

  createAuthors authorsNames, lang
  .then (createdAuthors)->
    createdAuthorsUris = createdAuthors.map _.property('id')
    claims =
      # instance of (P31) -> book (Q571)
      'wdt:P31': ['wd:Q571']
      P50: authors.concat createdAuthorsUris

    return createEntity labels, claims

createWorkEdition = (workEntity, isbn)->
  _.types arguments, ['object', 'string']

  books_.getIsbnData isbn
  .then (isbnData)->
    claims =
      # instance of (P31) -> edition (Q3331189)
      'wdt:P31': ['wd:Q3331189']
      # isbn 13 (isbn 10 will be added by the server)
      'wdt:P212': [ isbnData.isbn13 ]
      # edition or translation of (P629) -> created book
      'wdt:P629': [ workEntity.get('uri') ]

    return createEntity {}, claims
    .then (editionEntity)->
      workEntity.subentities['wdt:P629'].add editionEntity
      return editionEntity

byProperty = (options)->
  { property, textValue, lang } = options
  lang or= app.user.lang
  switch property
    when 'wdt:P50' then return createAuthor textValue, lang
    else
      message = "no entity creation function associated to this property"
      throw error_.new message, arguments

createEntity = (labels, claims)->
  _.types arguments, 'objects...'
  app.entities.data.inv.local.post
    labels: labels
    claims: claims
  .then (entityData)-> new InvEntity entityData

module.exports =
  create: createEntity
  book: createBook
  workEdition: createWorkEdition
  author: createAuthor
  byProperty: byProperty
