StaticController = require '../controllers/static'

module.exports = -> (error, req, res, next) ->
  console.error error.stack
  StaticController.handle {controller: 'static', action: 'error', error: error}, req, res, (err) ->
    return res.send 500, "UNKNOWN ERROR" if err
