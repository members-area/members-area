fs = require 'fs'
Sequelize = require 'sequelize'
_ = require 'underscore'
require '../env'
config = require('../config/config.json')[process.env.NODE_ENV]
async = require('async')

sequelize = new Sequelize config.database, config.username, config.password, _.defaults config,
  define:
    charset: 'utf8'
    collate: 'utf8_general_ci'
    classMethods:
      seed: (callback) ->
        @count().done (err, count) =>
          return callback err if err
          return callback() if count > 0
          # No data, so seed away.
          return callback() unless @seedData
          console.log "Seeding #{model.name}"
          create = (entry, done) =>
            @create(entry).done done
          async.mapSeries @seedData, create, callback

sequelize.membersMeta =
  type: Sequelize.TEXT
  allowNull: false
  defaultValue: "{}"
  get: ->
    try
      return JSON.parse @getDataValue('meta')
    catch
      return {}
  set: (v) ->
    v = {} if v is "{}"
    throw new Error("Can only set meta to object.") unless typeof v is 'object'
    @setDataValue('meta', JSON.stringify(v))
    return

exports.sequelize = sequelize

fs.readdirSync(__dirname).forEach (filename) ->
  [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
  return if name is 'index' or name.substr(0,1) is '.'
  return unless ext?.length
  model = sequelize.import "#{__dirname}/#{name}"
  exports[model.name] = model

exports.middleware = -> (req, res, next) ->
  req[k] = v for own k, v of exports
  next()

exports.User.hasMany exports.RoleUser
exports.Role.hasMany exports.RoleUser
