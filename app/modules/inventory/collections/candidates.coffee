module.exports = Backbone.Collection.extend
  model: require '../models/candidate'

  setAllSelectedTo: (bool)->
    @each (model)->
      # Do not set selected=true for invalid ISBNs candidates
      unless model.get('isInvalid') then model.set 'selected', bool

  getSelected: -> @filter (model)-> model.get('selected')
  getSelectedCount: -> @getSelected().length
