import preq from 'lib/preq'
import addPertinanceScore from './add_pertinance_score'
const searchWorks = require('modules/entities/lib/search/search_type').default('works')
const descendingPertinanceScore = work => -work.get('pertinanceScore')
const Suggestions = Backbone.Collection.extend({ comparator: descendingPertinanceScore })

export default function (serie) {
  const authorsUris = serie.getAllAuthorsUris()
  return Promise.all([
    getAuthorsWorks(authorsUris),
    searchMatchWorks(serie)
  ])
  .then(_.flatten)
  .then(_.uniq)
  .then(uris => app.request('get:entities:models', { uris, refresh: true }))
  // Confirm the type, as the search might have failed to unindex a serie that use
  // to be considered a work
  .filter(isWorkWithoutSerie)
  .map(addPertinanceScore(serie))
  .filter(work => work.get('authorMatch') || work.get('labelMatch'))
  .then(works => new Suggestions(works))
};

const getAuthorsWorks = authorsUris => Promise.all(authorsUris.map(fetchAuthorWorks))
.map(results => _.pluck(results.works.filter(hasNoSerie), 'uri'))
.then(_.flatten)

const fetchAuthorWorks = authorUri => preq.get(app.API.entities.authorWorks(authorUri))

const hasNoSerie = work => work.serie == null

const isWorkWithoutSerie = work => (work.get('type') === 'work') && (work.get('claims.wdt:P179') == null)

const searchMatchWorks = function (serie) {
  const serieLabel = serie.get('label')
  const { allUris: partsUris } = serie.parts
  return searchWorks(serieLabel, 20)
  .filter(result => (result._score > 0.5) && !partsUris.includes(result.uri))
  .map(_.property('uri'))
}
