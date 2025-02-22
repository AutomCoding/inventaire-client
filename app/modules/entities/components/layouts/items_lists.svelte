<script>
  import { icon } from '#lib/utils'
  import ItemsMap from '#map/components/items_map.svelte'
  import { i18n } from '#user/lib/i18n'
  import ItemsByCategories from './items_lists/items_by_categories.svelte'
  import { getItemsData } from './items_lists/items_lists_helpers'
  import { createEventDispatcher } from 'svelte'
  import { BubbleUpComponentEvent } from '#lib/svelte/svelte'

  const dispatch = createEventDispatcher()
  const bubbleUpComponentEvent = BubbleUpComponentEvent(dispatch)

  export let editionsUris, initialItems = [], itemsUsers, showMap, itemsByEditions, mapWrapperEl, itemsListsWrapperEl

  let items = []
  let initialBounds
  let waitingForItems

  // showMap is falsy to be able to mount ItemsByCategories
  // to set initialBounds before mounting ItemsMap
  showMap = false

  let fetchedEditionsUris = []
  const getItemsByCategories = async () => {
    const newUris = _.difference(editionsUris, fetchedEditionsUris)
    if (newUris.length === 0) return
    fetchedEditionsUris = [ ...editionsUris, ...newUris ]
    waitingForItems = getItemsData(newUris)
    initialItems = await waitingForItems
    items = initialItems
  }

  $: itemsUsers = _.compact(_.uniq(items.map(_.property('owner'))))
  $: itemsByEditions = _.groupBy(initialItems, 'entity')
  $: editionsUris && getItemsByCategories()
  $: displayCover = editionsUris?.length > 1
</script>

<div class="items-lists-wrapper" bind:this={itemsListsWrapperEl}>
  <ItemsByCategories
    {initialItems}
    {displayCover}
    {waitingForItems}
    bind:initialBounds
    bind:itemsOnMap={items}
    on:showMapAndScrollToMap={bubbleUpComponentEvent}
  />
</div>

{#if showMap}
  <div class="map-wrapper" bind:this={mapWrapperEl}>
    <ItemsMap
      docsToDisplay={items}
      initialDocs={initialItems}
      {initialBounds}
    />
    <button
      on:click={() => showMap = false}
      class="close-map-button"
      title={i18n('Close map')}
    >
      {@html icon('close')}
    </button>
  </div>
{/if}

<style lang="scss">
  @import "#general/scss/utils";
  .map-wrapper, .items-lists-wrapper{
    align-self: stretch;
  }
  .map-wrapper{
    // Set to the .simple-map height to allow to scroll to the right level
    // before the map is rendered
    padding: 0.5em;
    min-height: 30em;
    position: relative;
    background-color: $off-white;
  }
  .close-map-button{
    @include position(absolute, 1rem, 1rem);
    // Above .leaflet-pane
    z-index: 401;
    padding: 0.2rem;
    margin: 0;
    font-size: 1.2rem;
    @include bg-hover(white);
    @include radius;
  }
  /* Small screens */
  @media screen and (max-width: $small-screen){
    .close-map-button{
      padding: 0.3em;
    }
  }
</style>
