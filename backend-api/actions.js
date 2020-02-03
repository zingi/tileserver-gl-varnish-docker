const exec = require('shelljs.exec')
const debug = require('debug')('backend-api:actions')

module.exports = {
  /**
   * Tells the pm2 process manager to restart the tileserver.
   */
  async restartTileserver () {
    debug('Restarting tileserver ...')
    const out = exec('pm2 restart tileserver')
    return handleCommandOutput(out)
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
