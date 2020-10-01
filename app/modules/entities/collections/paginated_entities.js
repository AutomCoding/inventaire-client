import Entities from './entities'

export default Entities.extend({
  initialize (models, options = {}) {
    const { uris } = options
    if (uris == null) { throw new Error('expected uris') }
    // Clone the array as it will be mutated
    this.allUris = uris.slice(0)
    // At the begining, all URIs are unfetched URIs
    this.remainingUris = this.allUris
    this.totalLength = uris.length
    this.fetchedUris = [];
    ({ refresh: this.refresh, defaultType: this.defaultType, parentContext: this.parentContext } = options)
    return this.typesAllowlist != null ? this.typesAllowlist : (this.typesAllowlist = options.typesAllowlist)
  },

  resetFromUris (uris) {
    this.remainingUris = uris
    this.reset()
    return this.fetchMore()
  },

  fetchMore (amount = 10) {
    const urisToFetch = this.remainingUris.splice(0, amount)
    const fetchedUrisBefore = this.fetchedUris
    this.fetchedUris = this.fetchedUris.concat(urisToFetch)

    const rollback = err => {
      this.remainingUris = urisToFetch.concat(this.remainingUris)
      this.fetchedUris = fetchedUrisBefore
      return _.error(err, 'failed to fetch more works: rollback')
    }

    return app.request('get:entities:models', {
      uris: urisToFetch,
      refresh: this.refresh,
      defaultType: this.defaultType
    }).filter(this.filterOutUndesiredTypes.bind(this))
    .then(this.add.bind(this))
    .catch(rollback)
  },

  fetchAll () { return this.fetchMore(this.remainingUris.length) },

  firstFetch (amount) {
    if (!this._firstFetchDone) {
      this._firstFetchDone = true
      return this.fetchMore(amount)
    }
  },

  more () { return this.remainingUris.length },

  filterOutUndesiredTypes (entity) {
    if ((this.typesAllowlist == null) || this.typesAllowlist.includes(entity.type)) {
      return true
    } else {
      app.execute('report:entity:type:issue', {
        model: entity,
        expectedType: this.typesAllowlist,
        context: {
          module: module.id,
          allUris: JSON.stringify(this.allUris),
          parentContext: (this.parentContext != null) ? JSON.stringify(this.parentContext) : undefined
        }
      })
      return false
    }
  }
})
