<script>
  import { i18n } from '#user/lib/i18n'
  import { icon } from '#lib/utils'
  import Dropdown from '#components/dropdown.svelte'
  import { screen } from '#lib/components/stores/screen'
  import EntityLayoutActions from '#entities/components/layouts/entity_layout_actions.svelte'

  export let entity, showEntityEditButtons
</script>

{#if $screen.isLargerThan('$small-screen')}
  <ul class="large-screen-actions">
    <EntityLayoutActions bind:entity {showEntityEditButtons} />
  </ul>
{:else}
  <div class="small-screen-actions">
    <Dropdown
      align="right"
      buttonTitle={i18n('Show actions')}
      clickOnContentShouldCloseDropdown={true}
    >
      <div slot="button-inner">
        {@html icon('cog')}
      </div>
      <ul slot="dropdown-content">
        <EntityLayoutActions bind:entity {showEntityEditButtons} />
      </ul>
    </Dropdown>
  </div>
{/if}

<style lang="scss">
  @import "#general/scss/utils";
  .large-screen-actions{
    @include display-flex(row, flex-end);
    :global(a), :global(button){
      @include display-flex(row, center);
      @include tiny-button($off-white);
      height: 1.5em;
      padding: 1.2em 1em;
      margin: 0.5em;
    }
    :global(.fa){
      color: grey;
      font-size: 1.4rem;
    }
    :global(.link-text), :global(.button-text){
      display: none;
    }
  }
  .small-screen-actions{
    :global(.dropdown-button){
      @include tiny-button($grey);
      padding: 0.5em;
    }
  }
  [slot="dropdown-content"]{
    @include shy-border;
    background-color: white;
    @include radius;
    // z-index known cases: items map
    z-index: 1;
    position: relative;
    :global(li){
      @include display-flex(row, stretch, flex-start);
      &:not(:last-child){
        margin-bottom: 0.2em;
      }
    }
    :global(a), :global(button){
      flex: 1;
      @include display-flex(row, center, flex-start);
      min-height: 3em;
      @include bg-hover(white, 10%);
      padding: 0 1em;
    }
    :global(.fa){
      margin-right: 0.5rem;
    }
  }
</style>
