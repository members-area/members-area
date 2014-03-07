path = require 'path'

class Router
  constructor: (@app) ->
    @app.addRoute = @addRoute
    methods = {}
    for method in ['get', 'post', 'all']
      methods[method] = => @addRoute method, arguments...
    require('./routes')(methods)
    return

  addRoute: (method, path, args...) =>
    params = @parseParams args...
    @app[method] path, @handler params
    return

  parseParams: (args...) ->
    params = {}
    for arg in args
      switch (typeof arg)
        when 'string'
          parts = arg.split "#"
          switch parts.length
            when 2
              [controller, action] = parts
            when 3
              [plugin, controller, action] = parts
            else
              throw new Error "Invalid route string."
          params.plugin = plugin if plugin?
          params.controller = controller if controller?
          params.action = action if action?
        when 'object'
          params[k] = v for own k, v of arg
        else
          throw new Error "Invalid route."
    return params

  handler: (params) ->
    return (req, res, next) ->
      try
        throw new req.HTTPError(404) unless params.controller? and params.action?
        if params.plugin
          Plugin = require './plugin'
          plugin = Plugin.load params.plugin
          Controller = require("#{plugin.path}/controllers/#{params.controller}")
        else
          Controller = require("./controllers/#{params.controller}")
        Controller.handle params, req, res, next
      catch e
        next e

module.exports = (app) -> new Router app
