<script>
  import ItemsByCategory from './items_by_category.svelte'
  import { categoriesHeaders, sortItemsByCategorieAndDistance } from './items_lists_helpers'
  import { isNonEmptyArray } from '#lib/boolean_tests'
  import { createEventDispatcher, getContext } from 'svelte'
  import { icon } from '#lib/handlebars_helpers/icons'
  import { I18n, i18n } from '#user/lib/i18n'
  import { scrollToElement } from '#lib/screen'

  export let initialItems
  export let itemsOnMap
  export let initialBounds
  export let displayCover
  export let waitingForItems

  const dispatch = createEventDispatcher()
  let itemsByCategories = {}
  const showItemsOnMap = () => {
    itemsOnMap = itemsOnMap
    dispatch('showMapAndScrollToMap')
  }

  const updateItems = () => {
    itemsByCategories = sortItemsByCategorieAndDistance(initialItems)
    if (isNonEmptyArray(itemsByCategories.nearbyPublic)) {
      initialBounds = itemsByCategories.nearbyPublic.map(_.property('position'))
    }
  }

  const filters = getContext('work-layout:filters-store')

  let filtersTopEl
  function resetFilter (name) {
    $filters[name] = 'all'
    // Mitigate a scroll jump due to the edition list above being updated
    scrollToElement(filtersTopEl, { marginTop: 32 })
  }

  $: initialItems && updateItems()
  $: hasActiveFilter = $filters?.selectedLangLabel || $filters?.selectedPublisherLabel
</script>

<div class="filters-top" bind:this={filtersTopEl} />
{#if hasActiveFilter}
  <div class="filters-wrapper">
    <div class="filters">
      <span>{i18n('Active filters')}</span>
      {#if $filters.selectedLangLabel}
        <button
          class="tiny-button grey"
          title={I18n('reset filter')}
          aria-controls="language-filter"
          on:click={() => resetFilter('selectedLang')}
        >
          {@html icon('close')}
          {i18n('language')}:
          {$filters.selectedLangLabel}
        </button>
      {/if}
      {#if $filters.selectedPublisherLabel}
        <button
          class="tiny-button grey"
          title={I18n('reset filter')}
          aria-controls="publisher-filter"
          on:click={() => resetFilter('selectedPublisher')}
        >
          {@html icon('close')}
          {i18n('publisher')}:
          {$filters.selectedPublisherLabel}
        </button>
      {/if}
      {#if $filters.selectedPublicationYear !== 'all'}
        <button
          class="tiny-button grey"
          title={I18n('reset filter')}
          aria-controls="publication-year-filter"
          on:click={() => resetFilter('selectedPublicationYear')}
        >
          {@html icon('close')}
          {i18n('publication year')}:
          {$filters.selectedPublicationYear}
        </button>
      {/if}
    </div>
  </div>
{/if}

<div class="items-lists">
  {#each Object.keys(categoriesHeaders) as category}
    <ItemsByCategory
      {category}
      {displayCover}
      {waitingForItems}
      headers={categoriesHeaders[category]}
      itemsByCategory={itemsByCategories[category]}
      bind:itemsOnMap
      on:showItemsOnMap={showItemsOnMap}
    />
  {/each}
</div>

<style lang="scss">
  @import "#general/scss/utils";
  .items-lists{
    width: 100%;
  }
  // Use a wrapper to be able to have flex-grow up to max-width AND margin=auto
  .filters-wrapper{
    align-self: stretch;
    @include display-flex(row, stretch);
  }
  .filters{
    max-width: 50em;
    flex: 1;
    margin: 0.5em auto;
    padding: 0.5em;
    background-color: $light-grey;
    @include radius;
    align-self: stretch;
    @include display-flex(row, center, flex-start);
    span{
      color: $label-grey;
    }
    button{
      margin: 0.5em;
      padding: 0.3em 0.4em 0.3em 0;
    }
  }
</style>
