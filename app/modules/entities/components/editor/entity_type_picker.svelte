<script>
  import { I18n } from '#user/lib/i18n'
  import { entityTypeNameBySingularType } from '#entities/lib/types/entities_types'

  export let type
</script>

<div class="type-picker" role="listbox">
  {#each Object.entries(entityTypeNameBySingularType) as [ t, name ]}
    <div
      role="option"
      aria-selected={type === t}
    >
      <button
        on:click={() => type = t}
        class:selected={type === t}
      >
        {I18n(name)}
      </button>
    </div>
  {/each}
</div>

<style lang="scss">
  @import "#general/scss/utils";
  .type-picker{
    flex: 1;
    text-align: center;
    @include display-flex(row, center, center, wrap);
    margin: 0.5em 0.5em 2em;
    white-space: nowrap;
  }
  [role="option"]{
    flex: 1 0 6em;
    max-width: 10em;
    margin: 0.1em;
  }
  button{
    @include big-button($grey);
    padding: 1em;
    width: 100%;
    &.selected{
      @include bg-hover(white, 0%);
      color: $dark-grey;
    }
  }
</style>
