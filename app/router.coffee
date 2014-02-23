class Router
  constructor: (@app) ->
    methods = {}
    for method in ['get', 'post', 'all']
      methods[method] = => @addRoute method, arguments...
    require('./routes')(methods)
    return

  addRoute: (method, path, args...) ->
    params = @parseParams args...
    @app[method] path, @handler params
    return

  parseParams: (args...) ->
    params = {}
    for arg in args
      switch (typeof arg)
        when 'string'
          [controller, action] = arg.split "#"
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
        Controller = require("./controllers/#{params.controller}")
        Controller.handle params, req, res, next
      catch e
        next e

module.exports = (app) -> new Router app
