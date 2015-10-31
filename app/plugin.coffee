EventEmitter = require('events').EventEmitter
fs = require 'fs'
path = require 'path'
async = require 'async'
migrator = require './lib/migrator'
_ = require 'underscore'
resolve = require('resolve').sync

class Plugin extends EventEmitter
  @plugins = {}

  @load: (moduleName, app) ->
    identifier = path.basename(moduleName)
    return @plugins[identifier] if @plugins[identifier]?
    @plugins[identifier] = new Plugin(identifier, app, moduleName)

  @hook: (app) ->
    app.pluginHooks = {}
    processHook = (hookName, options, callback) ->
      prioritisedHooks = app.pluginHooks[hookName] ? {}
      priorities = Object.keys prioritisedHooks
      priorities.sort (a, b) -> parseInt(a, 10) - parseInt(b, 10)
      handleHook = (hook, next) ->
        if hook.length is 1 # No callback, do it live!
          hook(options)
          return process.nextTick next
        done = ->
          done = -> # Prevent calling twice
          clearTimeout timer
          next()
        watchdog = ->
          console.warn "WARNING: '#{hookName}' hook required watchdog call."
          done()
        timer = setTimeout watchdog, 3000 # Give hook just 3 seconds to do its thang
        try
          hook options, done
        catch e
          console.error "ERROR: hook '#{hookName}' triggered an error (probably from a plugin): \n#{e.stack}"
          done(e)
      handlePriority = (priority, next) ->
        async.each prioritisedHooks[priority], handleHook, next
      async.eachSeries priorities, handlePriority, callback
    return (hookNamesString, options, callback) ->
      console.log "TRIGGERING HOOK: '#{hookNamesString}' with options: #{Object.keys(options).map( (k) -> "#{k}[#{typeof options[k]}]").join(", ")}" if process.env.DEBUG?
      hookNames = hookNamesString.split(" ")
      handleHookName = (hookName, next) ->
        processHook hookName, options, next
      async.each hookNames, handleHookName, callback

  constructor: (@identifier, @app = require('../index.coffee'), @moduleName = @identifier) ->
    @shortName = @identifier.replace /^members-area-/, ""
    @models = @app.models

    # Useful dependencies
    @express = require 'express'
    @async = async
    @_ = _

    if @moduleName.match(/^[./]/)
      @path = @moduleName
    else
      resolved = resolve(@identifier, basedir: "#{process.cwd()}", extensions: Object.keys(require.extensions))
      @path = path.dirname resolved
    try
      @meta = require "#{@path}/package.json"
      {@name, @version, main} = @meta
    @name ?= @identifier
    try
      _.extend @, require "#{@path}/#{main}"
    catch e
      console.error "Failed to load plugin: #{e?.stack ? e}"

  initialize: (done) ->
    done()

  migrate: (done) ->
    migrator.runMigration 'up', null, @identifier, done

  modelFilenames: (done) ->
    fs.readdir "#{@path}/models", (err, files = []) =>
      filenames = []
      files.forEach (filename) =>
        [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
        return if name is 'index' or name.substr(0,1) is '.'
        return unless ext?.length
        filenames.push "#{@path}/models/#{name}"
      done null, filenames

  load: (callback) ->
    @once 'load', callback if callback?
    fail = =>
      callback new Error "Plugin #{@identifier} failed to load correctly."
      callback = ->
    watchdog = setTimeout fail, 5000
    async.series [
      @migrate.bind(this)
      @loadSettings.bind(this)
      @initialize.bind(this)
    ], (err) =>
      clearTimeout watchdog
      if err
        console.error "Loading '#{@identifier}' plugin wasn't completely successful"
        console.error err
      @emit 'load'

  loadSettings: (callback) ->
    next = =>
      callback()
    settingName = "plugin.#{@identifier}"
    @models.Setting.find()
    .where(name:settingName)
    .first (err, @setting) =>
      throw err if err
      return next() if @setting
      data =
        name: settingName
        meta:
          settings: {}
      @models.Setting.create data, (err, @setting) =>
        throw err if err
        console.log "CREATED SETTING" if @setting
        return next() if @setting
        throw new Error("Couldn't create settings.")

  hook: (hookName, priority, callback) ->
    if typeof priority is 'function'
      callback = priority
      priority = null
    priority = parseInt(priority, 10)
    priority = 0 unless isFinite(priority)
    @app.pluginHooks[hookName] ?= {}
    @app.pluginHooks[hookName][priority] ?= []
    @app.pluginHooks[hookName][priority].push callback

  addCSS: (path) ->
    require('./middleware/stylus').imports.push path

  get: (setting) ->
    if setting?
      return @setting.meta.settings[setting]
    else
      return _.clone @setting.meta.settings

  set: (values, callback) ->
    throw new Error "Invalid call to plugin.set - first argument must be an object" unless typeof values is 'object'
    settings = @setting.meta.settings ? {}
    for k, v of values
      if v?
        settings[k] = v
      else
        delete settings[k]
    @setting.setMeta {settings}
    callback ?= (err) ->
      console.error err if err
    @setting.save callback

module.exports = Plugin
