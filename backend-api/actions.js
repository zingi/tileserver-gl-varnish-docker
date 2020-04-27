const exec = require('shelljs.exec')
const debug = require('debug')('backend-api:actions')

module.exports = {
  /**
   * Tells the pm2 process manager to restart the tileserver.
   */
  async restartTileserver () {
    debug('Restarting tileserver ...')

    // stop service and remove from process list
    const down = exec('pm2 stop tileserver && pm2 delete tileserver')
    const up = exec('pm2 start /root/ecosystem.config.js --only tileserver')

    // check exit code and error output of commands
    const downOut = handleCommandOutput(down)
    const upOut = handleCommandOutput(up)

    if (downOut === null && upOut === null) {
      // if everything was successful return null
      return (null)
    } else {
      const string = (downOut === null ? 'stop tileserver successful\n' : 'stop tileserver NOT successful\n') +
      (upOut === null ? 'starting tileserver successful' : 'starting tileserver NOT successful')

      return string
    }
  },

  /**
   * Purges the whole varnish cache.
   */
  async purgeCache () {
    debug('Purging whole varnish cache ...')
    const out = exec('varnishadm "ban req.url ~ /"')
    return handleCommandOutput(out)
  }
}

function handleCommandOutput (out) {
  if (out.code === 0) {
    return null
  } else {
    debug(out.error)
    return out.error
  }
}
