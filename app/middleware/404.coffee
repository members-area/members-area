StaticController = require '../controllers/static'

module.exports = -> (req, res, next) ->
  StaticController.handle {controller: 'static', action: '404'}, req, res, (err) ->
    return next err if err
