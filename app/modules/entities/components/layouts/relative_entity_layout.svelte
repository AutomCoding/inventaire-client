<script>
  import ImagesCollage from '#components/images_collage.svelte'
  import { loadInternalLink } from '#lib/utils'

  export let uri, entitiesByUris

  $: displayedEntity = entitiesByUris[uri]
</script>
{#if displayedEntity}
  <li>
    <a
      href={displayedEntity.pathname}
      on:click={loadInternalLink}
      data-data={JSON.stringify(displayedEntity.image)}
      class="entity-link"
    >
      {#if displayedEntity.image.url}
        <ImagesCollage imagesUrls={[ displayedEntity.image.url ]}
        />
      {/if}
      <div class="label-wrapper">
        <span class="label">{displayedEntity.label}</span>
      </div>
    </a>
  </li>
{/if}

<style lang="scss">
  @import "#general/scss/utils";
  $card-width: 6rem;
  $card-height: 8rem;

  li{
    margin: 0.2em;
  }
  .entity-link{
    display: block;
    width: $card-width;
    height: $card-height;
    background-size: cover;
    background-position: center center;
    @include display-flex(column, stretch, flex-end);
    :global(.images-collage){
      width: $card-width;
      height: $card-height;
    }
    &:hover{
      @include shadow-box;
    }
  }
  .label-wrapper{
    @include display-flex(column, stretch, center);
    background-color: #eaeaea;
  }
  .label{
    text-align: center;
    padding: 0.2em 0.1em;
    line-height: 1.1rem;
    max-height: $card-height;
    overflow: hidden;
  }
</style>
