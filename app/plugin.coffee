EventEmitter = require('events').EventEmitter
fs = require 'fs'
async = require 'async'
migrator = require './lib/migrator'

class Plugin extends EventEmitter
  constructor: (@app, @identifier) ->
    @dirname = "../plugins/#{@identifier}"
    try
      @meta = require "#{@dirname}/package.json"
      {@name, @version} = @meta
    @name ?= @identifier
    try
      @initialize = require "#{@dirname}"

  initialize: (done) ->
    done()

  migrate: (done) ->
    migrator.runMigration 'up', null, @identifier, done

  modelFilenames: (done) ->
    fs.readdir "#{@dirname}/models", (err, files = []) =>
      filenames = []
      files.forEach (filename) =>
        [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
        return if name is 'index' or name.substr(0,1) is '.'
        return unless ext?.length
        filenames.push "#{@dirname}/models/#{name}"
      done null, filenames

  load: (callback) ->
    @once 'load', callback if callback?
    async.series [
      @migrate.bind(this)
      @initialize.bind(this)
    ], =>
      @emit 'load'

module.exports = Plugin
