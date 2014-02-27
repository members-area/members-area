fs = require 'fs'
require '../env'
async = require 'async'
_ = require 'underscore'
orm = require 'orm'
orm_timestamps = require 'orm-timestamps'
orm_transaction = require 'orm-transaction'

orm.settings.set 'instance.returnAllErrors', false
orm.settings.set 'properties.required', false

groupErrors = (errors) ->
  errors = [errors] if typeof errors is 'object'
  return null unless errors?.length
  obj = {}
  for error in errors ? []
    obj[error.property] ?= []
    obj[error.property].push error
  return obj

applyCommonClassMethods = (klass) ->
  methods =
    _seed: (callback) ->
      @count (err, count) =>
        return callback err if err
        return callback() if count > 0
        # No data, so seed away.
        return callback() unless @seedData
        console.log "Seeding #{@modelName}"
        create = (entry, done) =>
          @create entry, done
        async.mapSeries @seedData, create, callback

    getLast: (callback) ->
      @find()
      .order('-id')
      .limit(1)
      .run (err, models) ->
        callback err, models?[0]

    groupErrors: groupErrors

  for k, v of methods
    klass[k] = v

validateAndGroup = (name, properties, opts) ->
  opts.methods ?= {}
  opts.methods.groupErrors = groupErrors
  opts.methods.validateAndGroup = (callback) ->
    @validate (err, errors) =>
      return callback err if err
      errors = @groupErrors errors
      callback err, errors
  opts.methods.setMeta = (changes) ->
    meta = _.clone @meta
    for key, value of changes
      if value?
        meta[key] = value
      else
        delete meta[key]
    @meta = meta
    return

getModelsForConnection = (app, db, done) ->
  db.use orm_timestamps,
    createdProperty: 'createdAt'
    modifiedProperty: 'updatedAt'
    dbtype: {type: 'date', time: true}
    now: -> new Date()
    persist: true

  db.use orm_transaction

  db.use (db, opts) -> {beforeDefine: validateAndGroup}

  db.applyCommonHooks = (hooks = {}) ->
    return hooks

  fs.readdir __dirname, (err, files) ->
    models = {}
    filenames = []
    files.forEach (filename) ->
      [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
      return if name is 'index' or name.substr(0,1) is '.'
      return unless ext?.length
      filenames.push "#{__dirname}/#{name}"

    getModelFilenamesFromPlugin = (plugin, next) ->
      plugin.modelFilenames next

    async.map app.plugins, getModelFilenamesFromPlugin, (err, list = []) ->
      filenames = filenames.concat moreFilenames ? [] for moreFilenames in list

      filenames.forEach (filename) ->
        model = require(filename)(db, models)
        applyCommonClassMethods model
        models[model.modelName] = model

      models.RoleUser.hasOne 'user', models.User, reverse: 'roleUsers'
      models.RoleUser.hasOne 'role', models.Role, reverse: 'roleUsers', autoFetch: true
      done null, models


module.exports = getModelsForConnection
module.exports.middleware = -> (req, res, next) ->
  orm.connect process.env.DATABASE_URL, (err, db) ->
    return next err if err
    req.db = db
    getModelsForConnection req.app, db, (err, _models) ->
      req.models = _models
      next()
