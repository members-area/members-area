require('source-map-support').install()
express = require 'express'
http = require 'http'
path = require 'path'
fs = require 'fs'
net = require 'net'
require './env' # Fix/load/check environmental variables

process.chdir __dirname

makeIntegerIfPossible = (str) ->
  return parseInt(str, 10) if str?.match?(/^[0-9]+$/)
  str

app = express()

app.set 'trust proxy', true # Required for nginx/etc
app.set 'port', makeIntegerIfPossible(process.env.PORT) ? 1337
app.set 'views', __dirname + '/views'
app.set 'view engine', 'jade'

app.use express.static(path.join(__dirname, 'public'))
app.use express.favicon(path.join(__dirname, 'public', 'img', 'favicon.png'))

app.use (req, res, next) ->
  req.app = app
  next()
app.use require('./logging')(app)
app.use require('./stylus')()
app.use require('./http-error')()
app.use express.bodyParser()
app.use express.methodOverride()
app.use express.cookieParser(process.env.SECRET ? String(Math.random()))
app.use express.session()
app.configure 'development', ->
  app.use express.errorHandler()
app.use require('./models').middleware()
app.use require('./passport').initialize()

require('./router')(app)

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

if require.main is module
  require('./models').Role.loadAll().done (err, roles) ->
    if err
      console.error "Error loading roles:", err
      process.exit 1
    app.roles = roles
    start()

module.exports = app
