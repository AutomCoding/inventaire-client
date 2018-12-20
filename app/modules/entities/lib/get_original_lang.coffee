wdLang = require 'wikidata-lang'
{ unprefixify } = require 'lib/wikimedia/wikidata'

langProperties = [
  'wdt:P103' # native language
  'wdt:P407' # language of work
  'wdt:P1412' # languages spoken, written or signed
  'wdt:P2439' # language (general)
  # About to be merged into wdt:P407
  'wdt:P364' # original language of work
]

module.exports = (claims)->
  langClaims = _.pick claims, langProperties
  if _.objLength(langClaims) is 0 then return

  originalLangUri = _.pickOne(langClaims)?[0]
  if originalLangUri?
    wdId = unprefixify originalLangUri
    return wdLang.byWdId[wdId]?.code
