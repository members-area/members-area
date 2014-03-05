# Based on https://github.com/tnantoka/connect-fs

fs = require 'fs'
path = require 'path'
events = require 'events'
async = require 'async'

oneDay = 24*60*60*1000

module.exports = (connect) ->
  Store = connect.session.Store

  class FSStore extends Store
    constructor: (options = {}) ->
      super
      @client = new events.EventEmitter()
      @dir = options.dir ? "./sessions"
      fs.stat @dir, (err, stats) =>
        if stats and stats.isDirectory()
          return @client.emit "connect"
        fs.mkdir @dir, 0o755, (err) =>
          throw err if err
          return @client.emit "connect"
      return

    get: (sid, fn) ->
      attempts = 0
      do nextAttempt = =>
        attempts++
        fs.readFile path.join(@dir, "#{sid}.json"), "utf8", (err, data) ->
          return fn() if err?.code is 'ENOENT'
          try
            throw err if err
            data = JSON.parse(data)
            return fn null, data.session if data.expiryTime >= +new Date()
            return fn null, null
          catch e
            if attempts > 3
              return fn(err) # deliberately not 'e'
            else
              return setTimeout nextAttempt, 0
      return

    set: (sid, sess, fn) ->
      try
        data =
          expiryTime: +new Date() + (sess.cookie.maxAge ? oneDay)
          session: sess
        fs.writeFile path.join(@dir, "#{sid}.json"), JSON.stringify(data, null, 2), (err) ->
          fn? err, !err
      catch e
        fn? e

    destroy: (sid, fn) ->
      fs.unlink path.join(@dir, "#{sid}.json"), fn

    length: (fn) ->
      fs.readdir @dir, (err, files) ->
        return fn err if err
        length = 0

        for file in files
          length++ if /\.json$/.test(file)

        return fn null, length
      return

    clear: (fn) ->
      count = 0
      @length (err, length) =>
        fs.readdir @dir, (err, files) =>
          return fn err if err

          unlink = (file, fn) ->
            if /\.json$/.test(file)
              fs.unlink path.join(@dir, file), fn
            else
              process.nextTick fn

          async.map files, unlink, (err) ->
            return fn err, !err

          return

      return

  return FSStore
