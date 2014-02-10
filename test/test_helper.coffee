process.env.NODE_ENV ?= "test"
chai = require 'chai'
expect = chai.expect
sinon = require 'sinon'
models = require('../models')
Sequelize = require 'sequelize'

# Why would you not want this?!
chai.Assertion.includeStack = true

module.exports = {chai, expect, models, sinon, Sequelize}
module.exports[k] ?= v for k, v of models
