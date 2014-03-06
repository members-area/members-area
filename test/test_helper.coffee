require '../app/lib/coffee-support'
process.env.NODE_ENV ?= 'test'
process.env.SECRET ?= String(Math.random()) + "|" + String(Math.random()) + "|" + String(Math.random())
process.env.SERVER_ADDRESS ?= "http://example.com"
if process.env.NODE_ENV isnt 'test'
  console.error "Aborting test because environment is wrong: #{process.env.NODE_ENV}"
  process.exit 1
fs = require 'fs'
http = require 'http'
async = require 'async'
chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
require '../app/env'
orm = require 'orm'
getModelsForConnection = require('../app/models')
roleFixtures = require './fixtures/role'

app = require '../index'
db = null
before (done) ->
  try
    fs.unlinkSync "#{__dirname}/../members-test.sqlite"
  migrator = require '../app/lib/migrator'
  async.series
    createDb: (next) => migrator.runMigration 'up', null, next
    connectToDb: (next) =>
      orm.connect process.env.DATABASE_URL, (err, _db) =>
        @_db = _db
        next()
    setModels: (next) =>
      getModelsForConnection app, @_db, (err, models) =>
        @_models = models
        next()
    generateExampleRoles: (next) =>
      Role = @_models.Role
      Role.create [
        roleFixtures.friend
        roleFixtures.trustee
        roleFixtures.supporter
        roleFixtures.member
      ], (err, roles) =>
        app.roles = roles
        next()
  , done

after ->
  @_db.close()

# Why would you not want this?!
chai.Assertion.includeStack = true

app.__defineGetter__ 'roles', ->
  return app._roles if app._roles
middlewares = [
  require('../app/middleware/logging')(app)
  require('../app/middleware/http-error')()
  require('../app/models').middleware()
  require('../app/lib/passport').initialize()
  require('../app/lib/passport').session()
]
reqres = (callback) ->
  req = new http.IncomingMessage
  res = new http.ServerResponse req
  # Apply middleware
  req.app = app
  iterator = (middleware, done) ->
    middleware(req, res, done)
  async.mapSeries middlewares, iterator, ->
    app.emailSetting =
      meta:
        settings:
          from_address: "example@example.com"
    app.mailTransport =
      sendMail: -> # XXX: make emails testable
    callback req, res
  return

workerWithArity = (worker, arity) ->
  switch arity
    when 0 then return worker
    when 1 then return (a) -> worker.apply this, arguments
    when 2 then return (a, b) -> worker.apply this, arguments
    when 3 then return (a, b, c) -> worker.apply this, arguments
    when 4 then return (a, b, c, d) -> worker.apply this, arguments
    else return (a, b, c, d, e) -> worker.apply this, arguments

catchErrors = (done, fn) ->
  worker = ->
    try
      fn.apply this, arguments
    catch e
      done(e)
  return workerWithArity worker, fn.length

stub = (obj, method, worker) ->
  oldMethod = obj[method]
  obj[method] = workerWithArity worker, oldMethod.length
  obj[method].restore = ->
    obj[method] = oldMethod

module.exports = {app, async, catchErrors, chai, expect, getModelsForConnection, reqres, sinon, stub}
