const Koa = require('koa')
const Router = require('@koa/router')
const routes = require('./routes')
const debug = require('debug')('backend-api:server')

const app = new Koa()
const router = new Router()

router.get('/', routes.test)
router.post('/reload', routes.reload)

app.use(router.routes()).use(router.allowedMethods())
app.listen(3000)
debug('Backend API server is listening on 3000')
