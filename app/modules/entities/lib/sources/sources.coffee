properties = require 'modules/entities/lib/properties'
typeSearch = require './type_search'

sources =
  humans: typeSearch 'humans'
  genres: typeSearch 'genres'
  topics: typeSearch 'topics'
  languages: typeSearch 'languages'

module.exports = (property)->
  { source } = properties[property]
  return sources[source]
