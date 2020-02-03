
const actions = require('./actions')

module.exports = {
  async test (ctx) {
    ctx.body = 'Hello backend api!'
  },

  /**
   * Should be called when the served .mbtiles files have changed.
   * Does restart the tileserver and than purges the whole cache.
   * @param {Object} ctx koa request context
   */
  async reload (ctx) {
    const restartTSOut = await actions.restartTileserver()
    const purgeCacheOut = await actions.purgeCache()

    if (restartTSOut === null && purgeCacheOut === null) {
      ctx.body = 'success'
    } else {
      const errMsg = `${restartTSOut === null ? '' : restartTSOut}\n${purgeCacheOut === null ? '' : purgeCacheOut}`
      ctx.throw(500, errMsg)
    }
  }
}
