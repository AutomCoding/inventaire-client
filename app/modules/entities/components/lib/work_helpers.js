import { authorsProps } from '#entities/components/lib/claims_helpers'

export const getPublishersUrisFromEditions = editions => {
  return _.uniq(_.compact(_.flatten(editions.map(edition => {
    return findFirstClaimValue(edition, 'wdt:P123')
  }))))
}

export const removeAuthorsClaims = claims => {
  return omitClaims(claims, authorsProps)
}

export const omitClaims = (claims, properties) => {
  return _.omit(claims, properties.flat())
}

const findFirstClaimValue = (entity, prop) => {
  const values = entity?.claims[prop]
  if (!values || !values[0]) return
  return values[0]
}
