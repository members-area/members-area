require('source-map-support').install()
process.env.NODE_ENV ?= "test"
fs = require 'fs'
http = require 'http'
async = require 'async'
chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'

process.chdir "#{__dirname}/.."

config = require('../config/config.json')[process.env.NODE_ENV]
try
  fs.unlinkSync config.storage

models = require('../models')
Sequelize = require 'sequelize'

models.sequelize.sync()

# Why would you not want this?!
chai.Assertion.includeStack = true

app = require '../index'
app.__defineGetter__ 'roles', ->
  return app._roles if app._roles
  Role = models.Role
  baseRole = Role.build
    id: 1
    name: 'Base'
  friendRole = baseRole
  supporterRole = Role.build
    id: 2
    name: 'Supporter'
  memberRole = Role.build
    id: 3
    name: 'Member'
  trusteeRole = Role.build
    id: 4
    name: 'Trustee'
  ownerRole = trusteeRole
  supporterRole.meta =
    requirements: [
      {
        type: 'role'
        roleId: friendRole.id
      }
      # XXX: Change this to something that detects payment
      {
        type: 'text'
        text: 'A payment has been made'
      }
      {
        type: 'approval'
        roleId: trusteeRole.id
        count: 1
      }
    ]
  memberRole.meta =
    requirements: [
      {
        type: 'role'
        roleId: friendRole.id
      }
      {
        type: 'role'
        roleId: supporterRole.id
      }
      {
        type: 'approval'
        roleId: trusteeRole.id
        count: 3
      }
      {
        type: 'text'
        text: "Legal name proved to a trustee"
      }
      {
        type: 'text'
        text: "Home address proved to a trustee"
      }
    ]
  trusteeRole.meta =
    requirements: [
      {
        type: 'role'
        roleId: memberRole.id
      }
      {
        type: 'text'
        text: "voted in by the membership"
      }
      {
        type: 'approval'
        roleId: 20
        count: 3
      }
    ]
  baseRole.meta =
    requirements: [
      {
        type: 'approval'
        roleId: trusteeRole.id
        count: 1
      }
    ]
  roles = [friendRole, supporterRole, memberRole, trusteeRole]
  roles.base = baseRole
  roles.owner = ownerRole
  Role.roles = roles
  app._roles = roles
  return roles

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
  return ->
    try
      fn.call @, arguments
    catch e
      done(e)

module.exports = {app, catchErrors, chai, expect, models, reqres, sinon, Sequelize}
module.exports[k] ?= v for k, v of models
