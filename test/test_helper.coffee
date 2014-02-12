require('source-map-support').install()
process.env.NODE_ENV ?= "test"
fs = require 'fs'
http = require 'http'
async = require 'async'
chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'

config = require('../config/config.json')[process.env.NODE_ENV]
try
  fs.unlinkSync config.storage

models = require('../models')
Sequelize = require 'sequelize'

models.sequelize.sync()

# Why would you not want this?!
chai.Assertion.includeStack = true

module.exports = {chai, expect, models, sinon, Sequelize}
module.exports[k] ?= v for k, v of models
