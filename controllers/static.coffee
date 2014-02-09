Controller = require '../controller'

module.exports = class StaticController extends Controller
  home: ->
    if @req.user?
      @redirectTo "/dashboard", status: 307
    else
      @redirectTo "/register", status: 307
