require('source-map-support').install()
process.env.NODE_ENV ?= 'test'
if process.env.NODE_ENV isnt 'test'
  console.error "Aborting test because environment is wrong: #{process.env.NODE_ENV}"
  process.exit 1
fs = require 'fs'
http = require 'http'
async = require 'async'
chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
require '../env'
orm = require 'orm'
getModelsForConnection = require('../models')
roleFixtures = require './fixtures/role'

app = require '../index'
db = null
before (done) ->
  fs.unlinkSync "#{__dirname}/../members-test.sqlite"
  migrator = require '../lib/migrator'
  async.series
    createDb: (next) => migrator.runMigration 'up', null, next
    connectToDb: (next) =>
      orm.connect process.env.DATABASE_URL, (err, _db) =>
        @_db = _db
        next()
    setModels: (next) =>
      getModelsForConnection @_db, (err, models) =>
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

# Why would you not want this?!
chai.Assertion.includeStack = true

app.__defineGetter__ 'roles', ->
  return app._roles if app._roles
reqres = (callback) ->
  req = new http.IncomingMessage
  res = new http.ServerResponse req
  # Apply middleware
  req.app = app
  middlewares = [
    require('../logging')(req.app)
    require('../http-error')()
    require('../models').middleware()
  ]
  iterator = (middleware, done) ->
    middleware(req, res, done)
  async.mapSeries middlewares, iterator, ->
    callback req, res
  return

catchErrors = (done, fn) ->
  worker = ->
    try
      fn.apply this, arguments
    catch e
      done(e)
  switch fn.length
    when 0 then return worker
    when 1 then return (a) -> worker.apply this, arguments
    when 2 then return (a, b) -> worker.apply this, arguments
    when 3 then return (a, b, c) -> worker.apply this, arguments
    when 4 then return (a, b, c, d) -> worker.apply this, arguments
    else return (a, b, c, d, e) -> worker.apply this, arguments

module.exports = {app, catchErrors, chai, expect, getModelsForConnection, reqres, sinon}
