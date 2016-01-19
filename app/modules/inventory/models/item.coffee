Filterable = require 'modules/general/models/filterable'

module.exports = Filterable.extend
  url: -> app.API.items.base

  validate: (attrs, options)->
    unless attrs.title? then return "a title must be provided"
    unless attrs.owner? then return "a owner must be provided"

  initialize: (attrs, options)->
    # RECIPE:
      # entity = entity "#{domain}:#{id} uri
      # pathname = "#{username}/#{entity}/#{title}
    # - allows entity uri to be used in pathname
    # nice for super users/wikidata wizzards
    # - opened issue: the couple username/entity-uri to build the pathname
    # close the possibility to have several instances of a single entity

    {entity, title, owner} = attrs

    unless entity?
      throw new Error "item should have an associated entity"

    entityUri = app.request 'normalize:entity:uri', entity
    # make sure the entity model is loaded in the global Entities collection
    # and thus accessible from a Entities.byUri
    @waitForEntity = @reqGrab 'get:entity:model', entityUri, 'entity'

    # created will be overriden by the server at item creation
    attrs.created = @get('created') or _.now()
    attrs._id = @getId(attrs)

    @set attrs

    @username = app.request 'get:username:from:userId', owner
    @profilePic = app.request 'get:profilePic:from:userId', owner
    [ @canonical, @pathname ] = @buildPathname attrs
    @restricted = owner isnt app.user.id
    @entityPathname = app.request 'get:entity:local:href', entityUri, title

  getId: (attrs)->
    if @get('_id') then return @get('_id')
    else return 'new'

  buildPathname: (attrs)->
    if @username? and attrs.entity?
      canonical = pathname = "/inventory/#{@username}/#{attrs.entity}"
      title = _.softEncodeURI @get('title')
      pathname += "/#{title}"  if title?
      return [canonical, pathname]
    else
      return []

  serializeData: ->
    attrs = @toJSON()
    _.extend attrs,
      pathname: @pathname
      entityData: @entity?.toJSON()
      entityPathname: @entityPathname
      restricted: @restricted
      user:
        username: @username
        profilePic: @profilePic
        pathname: "/inventory/#{@username}"

    attrs.currentTransaction = Items.transactions[attrs.transaction]
    attrs[attrs.transaction] = true
    unless attrs.restricted
      attrs.transactions = Items.transactions
      attrs.listings = app.user.listings
      attrs.uiId = _.uniqueId('item_')
      if attrs.listing?
        attrs.currentListing = app.user.listings[attrs.listing]
      else
        # main user item fetched from a public API
        # requires to borrow its listing to the private item
        listing = app.request('get:item:model', attrs._id)?.get('listing')
        attrs.currentListing = app.user.listings[listing]

    # picture may be undefined
    attrs.picture = attrs.pictures?[0]

    return attrs

  asMatchable: ->
    [
      @get('title')
      @get('username')
      @get('details')
      @get('notes')
      @get('entity')
    ]

  # passing id and rev as query paramaters
  destroy: ->
    # reproduce the behavior from the default Bacbkone::destroy
    @trigger 'destroy', @, @collection
    url = _.buildPath @url(),
      id: @id
      # TODO: rev isn't required anymore
      # this might make possible to use the default Backbone behavior
      rev: @get('_rev')
    return _.preq.delete url

  # to be called by a view onShow:
  # updates the document with the item data
  updateMetadata: ->
    # start by adding the entity's metadata
    # and then override by the data available on the item
    @waitForEntity
    # cant be @entity.updateMetadata.bind(@entity)
    # as @entity is probably undefined yet
    .then => @entity.updateMetadata()
    .then @executeMetadataUpdate.bind(@)

  executeMetadataUpdate: ->
    app.execute 'metadata:update',
      title: @findBestTitle()
      description: @findBestDescription()?[0..500]
      image: @get('pictures')?[0]
      url: @canonical

  findBestTitle: ->
    title = @get('title')
    transaction = @get 'transaction'
    context = _.i18n "#{transaction}_personalized", {username: @username }
    return "#{title} - #{context}"

  findBestDescription: ->
    details = @get('details')
    if _.isNonEmptyString(details) then details
