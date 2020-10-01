import preq from 'lib/preq'
// Request configuration to the server and make it accessible at app.config
export default () => preq.get(app.API.config)
.then(config => app.config = config)
