<script>
  import { I18n } from '#user/lib/i18n'
  import Link from '#lib/components/link.svelte'
  import { getCounterText } from '#entities/components/lib/edition_action_helpers'

  export let entity, itemsByEditions = {}

  const { uri, _id } = entity
  const url = `/entity/${uri}/add`

  // will break with #182 (remove edition from quarantine)
  const editionUri = `inv:${_id}`

  $: editionItems = itemsByEditions[editionUri]
</script>

<div class="edition-actions">
  <div class="add-to-my-inventory">
    <Link
      {url}
      text={I18n('add to my inventory')}
      icon="plus"
      classNames="action-button tiny-button"
    />
  </div>
  {#if editionItems}
    <div class="link-wrapper">
      <!-- insert itemsLists deeplink -->
      <Link
        url={`/entity/${uri}`}
        text={getCounterText(editionItems)}
        dark={true}
      />
    </div>
  {/if}
</div>
<style lang="scss">
  @import "#general/scss/utils";
  .edition-actions{
    @include display-flex(column, center, flex-end);
  }
  .add-to-my-inventory{
    :global(.action-button){
      @include tiny-button($light-blue);
      padding: 0.5em;
      white-space: nowrap;
    }
  }
  .link-wrapper{
    padding: 0.5em;
  }
  /* Small screens */
  @media screen and (max-width: $small-screen){
    .add-to-my-inventory{
      @include display-flex(row);
      margin-bottom: 0.5em;
    }
  }
</style>
