import { someMatch, isOpenedOutside, capitalize } from '#lib/utils'
import mergeSuggestionTemplate from './templates/merge_homonym.hbs'
import mergeSuggestionSubentityTemplate from './templates/merge_homonym_subentity.hbs'
import forms_ from '#general/lib/forms'
import error_ from '#lib/error'
import mergeEntities from './lib/merge_entities.js'
import { startLoading, stopLoading } from '#general/plugins/behaviors'
import '#entities/scss/merge_homonyms.scss'
import AlertBox from '#behaviors/alert_box'
import Loading from '#behaviors/loading'
import PreventDefault from '#behaviors/prevent_default'
import { buildPath } from '#lib/location'

export default Marionette.View.extend({
  template: mergeSuggestionTemplate,
  className: 'merge-homonym',
  behaviors: {
    AlertBox,
    Loading,
    PreventDefault,
  },

  regions: {
    series: '.seriesList',
    works: '.worksList'
  },

  initialize () {
    const toEntityUri = this.options.toEntity.get('uri')
    this.taskModel = this.model.tasks?.[toEntityUri]
    if (this.model.type) {
      this.isTypeAttribute = `is${capitalize(this.model.type)}`
    }
    this.isExactMatch = haveLabelMatch(this.model, this.options.toEntity)

    this.wikidataEntities = this.model.get('isWikidataEntity') && this.options.toEntity.get('isWikidataEntity')
    if (this.wikidataEntities) {
      const fromid = this.options.toEntity.get('uri').split(':')[1]
      const toid = this.model.get('uri').split(':')[1]
      this.wikidataMergeUrl = buildPath('https://www.wikidata.org/wiki/Special:MergeItems', { fromid, toid })
    }

    this.showCheckbox = this.options.showCheckbox && !this.wikidataEntities
  },

  serializeData () {
    const attrs = this.model.toJSON()
    attrs.task = this.taskModel?.serializeData()
    attrs[this.isTypeAttribute] = true
    attrs.isExactMatch = this.isExactMatch
    attrs.showCheckbox = this.showCheckbox
    attrs.wikidataEntities = this.wikidataEntities
    attrs.wikidataMergeUrl = this.wikidataMergeUrl
    return attrs
  },

  events: {
    'click .showTask': 'showTask',
    'click .merge': 'merge'
  },

  async onRender () {
    if (this.model.get('type') !== 'human') return
    await this.model.initAuthorWorks()
    if (this.isIntact()) this.showWorks()
  },

  showWorks () {
    this.showSubentities('series', this.model.works.series)
    this.showSubentities('works', this.model.works.works)
  },

  async showSubentities (name, collection) {
    if (collection.totalLength === 0) return
    await collection.fetchAll()
    if (this.isIntact()) this._showSubentities(name, collection)
  },

  _showSubentities (name, collection) {
    this.$el.find(`.${name}Label`).show()
    this.showChildView(name, new SubentitiesList({ collection, entity: this.model }))
  },

  showTask (e) {
    if (!isOpenedOutside(e)) {
      app.execute('show:task', this.taskModel.id)
    }
  },

  async merge () {
    if (this._mergedAlreadyTriggered) return
    this._mergedAlreadyTriggered = true

    startLoading.call(this)
    const { toEntity } = this.options
    const fromUri = this.model.get('uri')
    const toUri = toEntity.get('uri')

    return mergeEntities(fromUri, toUri)
    // Simply hidding it instead of removing it from the collection so that other
    // suggestions don't jump places, potentially leading to undesired merges
    .then(() => this.$el.css('visibility', 'hidden'))
    .finally(stopLoading.bind(this))
    .catch(error_.Complete('.merge', false))
    .catch(forms_.catchAlert.bind(null, this))
  },

  isSelected () { return this.$el.find('input[type="checkbox"]').prop('checked') }
})

const haveLabelMatch = (suggestion, toEntity) => someMatch(getNormalizedLabels(suggestion), getNormalizedLabels(toEntity))

const getNormalizedLabels = entity => Object.values(entity.get('labels')).map(normalizeLabel)
const normalizeLabel = label => label.toLowerCase().replace(/\W+/g, '')

const Subentity = Marionette.View.extend({
  className: 'subentity',
  template: mergeSuggestionSubentityTemplate,
  attributes () {
    return { title: this.model.get('uri') }
  },

  serializeData () {
    const attrs = this.model.toJSON()
    const authorUri = this.options.entity.get('uri')
    attrs.claims['wdt:P50'] = _.without(attrs.claims['wdt:P50'], authorUri)
    return attrs
  }
})

const SubentitiesList = Marionette.CollectionView.extend({
  className: 'subentities-list',
  childView: Subentity,
  childViewOptions () {
    return { entity: this.options.entity }
  }
})
