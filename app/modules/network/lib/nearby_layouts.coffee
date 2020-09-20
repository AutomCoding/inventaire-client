map_ = require 'modules/map/lib/map'
getPositionFromNavigator = require 'modules/map/lib/navigator_position'
{ updateRoute, updateRouteFromEvent, BoundFilter } = map_
containerId = 'mapContainer'
containerSelector = '#' + containerId
{ startLoading, stopLoading } = require 'modules/general/plugins/behaviors'

initMap = (params)->
  { view, query } = params

  # Do not redefine the updateRoute variable: access from params object
  params.updateRoute ?= true

  startLoading.call view, containerSelector

  Promise.all [
    solvePosition query
    app.request 'map:before'
  ]
  .tap stopLoading.bind(view, containerSelector)
  .spread drawMap.bind(null, params)
  .then initEventListners.bind(null, params)

solvePosition = (coords = {})->
  # priority is given to passed parameters
  { lat, lng, zoom } = coords
  if lat? and lng? then return Promise.resolve coords

  # then to the user saved position
  { user } = app
  if user.hasPosition() then return Promise.resolve user.getCoords()

  # finally a request for the user position is issued
  return getPositionFromNavigator containerId

drawMap = (params, coords)->
  { lat, lng, zoom } = coords
  { showObjects, path } = params

  map = map_.draw
    containerId: containerId
    latLng: [ lat, lng ]
    zoom: zoom
    cluster: true

  showObjects map

  if params.updateRoute then updateRoute path, lat, lng, zoom

  _.type map, 'object'
  return map

initEventListners = (params, map)->
  _.type map, 'object'
  { path, onMoveend } = params

  if params.updateRoute
    _.type path, 'string'
    map.on 'moveend', updateRouteFromEvent.bind(null, path)

  map.on 'moveend', onMoveend

  return map

module.exports =
  initMap: initMap

  regions:
    list: '#list'

  grabMap: (map)->
    _.type map, 'object'
    _.type map.getBounds, 'function'
    @map = map

  refreshListFilter: (collection)->
    collection = collection or @collection
    collection.filterBy 'geobox', BoundFilter(@map)

  solvePosition: solvePosition

  drawMap: drawMap
