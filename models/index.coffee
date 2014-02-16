fs = require 'fs'
require '../env'
async = require 'async'
orm = require 'orm'

orm.settings.set 'instance.returnAllErrors', false
orm.settings.set 'properties.required', false

applyCommonClassMethods = (klass) ->
  methods =
    _seed: (callback) ->
      @count().done (err, count) =>
        return callback err if err
        return callback() if count > 0
        # No data, so seed away.
        return callback() unless @seedData
        console.log "Seeding #{model.name}"
        create = (entry, done) =>
          @create(entry).done done
        async.mapSeries @seedData, create, callback
    getLast: ->
      @find
        order: [['id', 'DESC']]
        limit: 1

    groupErrors: (errors) ->
      errors = [errors] if typeof errors is 'object'
      return null unless errors?.length
      obj = {}
      for error in errors ? []
        obj[error.property] ?= []
        obj[error.property].push error
      return obj

  for k, v of methods
    klass[k] = v

getModelsForConnection = (db, done) ->
  db.applyCommonHooks = (hooks = {}) ->
    hooks.beforeValidation ?= []
    hooks.beforeValidation.push ->
      @updatedAt = new Date()
    return hooks
  fs.readdir __dirname, (err, files) ->
    models = {}
    files.forEach (filename) ->
      [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
      return if name is 'index' or name.substr(0,1) is '.'
      return unless ext?.length
      model = require("#{__dirname}/#{name}")(db, models)
      applyCommonClassMethods model
      models[model.modelName] = model

    models.RoleUser.hasOne models.User
    models.RoleUser.hasOne models.Role

    done null, models

module.exports = getModelsForConnection
module.exports.middleware = ->
  orm.express process.env.DATABASE_URL,
    define: (db, models, next) ->
      getModelsForConnection db, (err, _models) ->
        models[k] = v for own k, v of _models
        next()
