<script>
  import { formatEbooksClaim } from '#entities/components/lib/claims_helpers'
  import { isNonEmptyArray } from '#lib/boolean_tests'
  import { I18n, i18n } from '#user/lib/i18n'
  import Link from '#lib/components/link.svelte'
  import sitelinks_ from '#lib/wikimedia/sitelinks'

  export let entity

  let userLang = app.user.lang
  let { claims } = entity
  let ebooksData = []

  const formatAndAssignEbooks = prop => {
    const valuesData = formatEbooksClaim(claims[prop], prop)
    if (valuesData) ebooksData = [ ...ebooksData, ...valuesData ]
  }

  formatAndAssignEbooks('wdt:P2034')
  formatAndAssignEbooks('wdt:P724')
  formatAndAssignEbooks('wdt:P4258')

  const wikisourceLink = sitelinks_.wikisource(entity.sitelinks, userLang, entity.originalLang)
</script>
{#if isNonEmptyArray(ebooksData)}
  <div class="ebooks">
    <span>{I18n('ebooks')}:</span>
    {#each ebooksData as value}
      <Link
        url={value.url}
        html={value.text}
      />
    {/each}
    {#if wikisourceLink}
      <Link
        url={wikisourceLink.url}
        text={i18n('on Wikisource')}
        icon="wikisource"
      />
    {/if}
  </div>
{/if}
<style lang="scss">
  @import "#general/scss/utils";
  .ebooks{
    @include display-flex(row, center, flex-start, wrap);
    margin-top: 1em;
    :global(.icon){
      margin-left: 0.6em;
      margin-right: 0.4em;
    }
    :global(a){
      @include link-dark;
    }
  }
</style>
