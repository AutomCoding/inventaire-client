import preq from 'lib/preq'
const { escapeExpression } = Handlebars

export default {
  extract (lang, title) {
    return preq.get(app.API.data.wikipediaExtract(lang, title))
    .then(data => {
      let { extract, url } = data
      lang = url?.match(/^https:\/\/([\w-]+).wik/)?.[1]
      // Escaping as extracts are user-generated external content
      // that will be displayed as {{{SafeStrings}}} in views as
      // they are enriched with HTML by sourcedExtract hereafter
      extract = escapeExpression(extract)
      extract = sourcedExtract(extract, url)
      return { extract, lang }
    })
    .catch(_.ErrorRethrow('wikipediaExtract err'))
  }
}

// Add a link to the full wikipedia article at the end of the extract
const sourcedExtract = function (extract, url) {
  if ((extract != null) && (url != null)) {
    const text = _.i18n('read_more_on_wikipedia')
    extract += `<br><a href="${url}" class='source link' target='_blank'>${text}</a>`
  }

  return extract
}
