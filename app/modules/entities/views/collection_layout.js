import TypedEntityLayout from './typed_entity_layout.js'
import getEntitiesListView from './entities_list.js'
import GeneralInfobox from './general_infobox.js'
import PaginatedEntities from '#entities/collections/paginated_entities'
import collectionLayoutTemplate from './templates/collection_layout.hbs'
import collectionInfoboxTemplate from './templates/collection_infobox.hbs'
import '../scss/entities_layouts.scss'
import '../scss/entities_infoboxes.scss'
import '../scss/collection_layout.scss'

const Infobox = GeneralInfobox.extend({ template: collectionInfoboxTemplate })

export default TypedEntityLayout.extend({
  baseClassName: 'collectionLayout',
  tagName () {
    return this.options.tagName || 'div'
  },
  template: collectionLayoutTemplate,
  Infobox,
  regions: {
    infoboxRegion: '.collectionInfobox',
    editionsList: '#editionsList',
    mergeHomonymsRegion: '.mergeHomonyms'
  },

  async onRender () {
    TypedEntityLayout.prototype.onRender.call(this)
    const uris = await this.model.fetchSubEntitiesUris(this.refresh)
    if (!this.isIntact()) return
    this.showPaginatedEditions(uris)
  },

  serializeData () {
    return {
      standalone: this.standalone,
      displayMergeSuggestions: this.displayMergeSuggestions
    }
  },

  async showPaginatedEditions (uris) {
    const collection = new PaginatedEntities(null, { uris, defaultType: 'edition' })
    const view = await getEntitiesListView({
      collection,
      hideHeader: !this.standalone,
      compactMode: true,
      parentModel: this.model,
      type: 'edition',
      title: 'editions',
      addButtonLabel: 'add an edition to this collection'
    })
    this.showChildView('editionsList', view)
  }
})
