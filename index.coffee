require('source-map-support').install()
async = require 'async'
crypto = require 'crypto'
express = require 'express'
http = require 'http'
path = require 'path'
fs = require 'fs'
net = require 'net'
FSStore = require('./app/lib/connect-fs')(express)
Plugin = require './app/plugin'
require './app/env' # Fix/load/check environmental variables

makeIntegerIfPossible = (str) ->
  return parseInt(str, 10) if str?.match?(/^[0-9]+$/)
  str

app = express()
app.plugins = []
app.getPlugin = (id) ->
  return plugin for plugin in app.plugins when plugin.identifier is id
  return
app.pluginHook = Plugin.hook app
app.path = __dirname

app.set 'trust proxy', true # Required for nginx/etc
app.set 'port', makeIntegerIfPossible(process.env.PORT) ? 1337
app.locals.basedir = path.join __dirname, 'app', 'views'
app.set 'views', app.locals.basedir
app.set 'view engine', 'jade'

app.use express.static(path.join(__dirname, 'public'))
app.use express.favicon(path.join(__dirname, 'public', 'img', 'favicon.png'))

app.use (req, res, next) ->
  req.app = app
  res.locals.restartRequired = app.restartRequired ? false
  next()
app.use require('./app/middleware/logging')(app)
app.use require('./app/middleware/stylus')()
app.use require('./app/middleware/http-error')()
app.use express.bodyParser()
app.use express.methodOverride()
app.use express.cookieParser(process.env.SECRET)

sessionStore = new FSStore

app.use express.session
  secret: process.env.SECRET
  store: sessionStore

app.configure 'development', ->
  app.use express.errorHandler()
app.use require('./app/models').middleware()
app.use require('./app/lib/passport').initialize()
app.use require('./app/lib/passport').session()

app.use app.router
require('./app/router')(app)

app.use require('./app/middleware/404')()
app.use require('./app/middleware/error-handler')()

listen = (port) ->
  server = http.createServer(app)
  server.on 'error', (err) ->
    if err?.code is 'EADDRINUSE'
      app.logger.error "Port '#{port}' in use"
    else
      app.logger.error "Could not listen on socket '#{port}': #{err}"
    process.exit 1
  server.listen port, ->
    if typeof port is 'string'
      fs.chmod port, '0666'
    app.logger.info "Express server listening on port " + port

start = ->
  port = app.get('port')
  if typeof port is 'string'
    # Unix socket - see if it's in use
    socket = new net.Socket
    socket.on 'connect', ->
      app.logger.error "Socket in use"
      process.exit 1
    socket.on 'error', (err) ->
      if err?.code is 'ECONNREFUSED'
        # No-one's listening
        fs.unlink port, (err) ->
          if err
            app.logger.error "Couldn't delete old socket."
            process.exit 1
          app.logger.info "Liberated unused socket."
          listen port
      else if err?.code is 'ENOENT'
        listen port
      else
        app.logger.error "Could not listen on socket '#{port}': #{err}"
        process.exit 1
    socket.connect port
  else
    # TCP socket
    listen port

checkRoles = ->
  app.models.Role.find (err, roles) ->
    throw err if err
    for role in roles ? []
      hasBase = true if role.id is 1
      hasOwner = true if role.id is 2
    throw new Error("Required role is missing, try 'npm run setup'") unless hasBase and hasOwner
    start()

loadPlugins = ->
  fs.readdir 'plugins', (err, dirs = []) ->
    for dir in dirs
      try
        app.plugins.push new Plugin app, dir, app.models
      catch e
        console.error "Could not load '#{dir}' plugin: #{e}"
    loadPlugin = (plugin, done) ->
      plugin.load(done)
    async.map app.plugins, loadPlugin, (err) ->
      throw err if err
      checkRoles()

connectToDb = ->
  require('orm').connect process.env.DATABASE_URL, (err, db) ->
    throw err if err
    require('./app/models') app, db, (err, models) ->
      throw err if err
      app.globalDb = db
      app.models = models
      loadPlugins()

if require.main is module
  unless process.env.SECRET
    crypto.randomBytes 18, (err, bytes) ->
      console.error "ERROR: You must set the 'SECRET' environmental variable, e.g."
      console.error "    SECRET=\"#{bytes.toString('base64') ? "SecretStringHere"}\""
      process.exit 1
    return
  connectToDb()

module.exports = app
