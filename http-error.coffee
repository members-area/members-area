module.exports = -> (req, res, next) ->
  class req.HTTPError extends Error
    constructor: (@status, @message) ->
  next()
