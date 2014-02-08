class Router
  constructor: (@app) ->
    require('./routes')({@get, @post, @any})

  addRoute: (method, path, args...) ->
    @app[method] path, (req, res, next) ->
      err = new Error("Unimplemented")
      err.status = 501
      next err

  get: => @addRoute 'get', arguments...
  post: => @addRoute 'post', arguments...
  any: => @addRoute 'any', arguments...

module.exports = (app) -> new Router app
