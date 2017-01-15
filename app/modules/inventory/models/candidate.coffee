module.exports = Backbone.Model.extend
  initialize: ->
    @set 'selected', true

  createItem: (transaction, listing)->
    [ title, isbn, authors ] = @gets 'title', 'isbn', 'authors'

    app.request 'entity:exists:or:create:from:seed', { title, isbn, authors }
    .then ->
      itemModel = app.request 'item:create',
        title: title
        entity: "isbn:#{isbn}"
        transaction: transaction
        listing: listing

      itemModel._creationPromise
      # before resolving to the item model
      .then -> itemModel
