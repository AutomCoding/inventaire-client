<script>
  export let large = false, light = false, center = false
</script>

<!-- The "spinner" class is set on the outer elements to let it be style from parent components -->
{#if large}
  <div class="spinner spinner-outer"><div class="spinner-inner" /></div>
{:else if center}
  <div class="spinner spinner-centered">
    <span class="small-spinner" class:light />
  </div>
{:else}
  <span class="spinner small-spinner" class:light />
{/if}

<style>
  .spinner-outer{
    position: fixed;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
  }

  .spinner-inner{
    transform: translateY(-50%);
    display: inline-block;
    align-self: center;
  }

  .spinner-centered{
    text-align: center;
  }

  .small-spinner::after, .spinner-inner::after{
    content: " ";
    display: inline-flex;
    width: 1em;
    height: 1em;
    margin: 0 0.5em;
    border-radius: 50%;
    animation: ring-loader 1.2s linear infinite;
    border: 2px solid;
  }

  .spinner-inner::after{
    font-size: 5em;
    border-width: 8px;
    border-color: #222 #319cc2 #ffd402 transparent;
  }

  .small-spinner:not(.light)::after{
    border-color: #333 #333 #333 transparent;
  }

  .small-spinner.light::after{
    border-color: white white white transparent;
  }

  @keyframes ring-loader{
    0%{
      transform: rotate(0deg);
    }
    100%{
      transform: rotate(360deg);
    }
  }
</style>
