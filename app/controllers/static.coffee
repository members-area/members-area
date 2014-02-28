Controller = require '../controller'

module.exports = class StaticController extends Controller
  home: ->
    if @req.user?
      @redirectTo "/dashboard", status: 307
    else
      @redirectTo "/login", status: 307

  404: ->
    @template = '404-loggedin' if @loggedInUser?

  error: ->
    @status = @params.error?.status ? 500
    @errorMessage =
      switch @status
        when 500
          "Internal Server Error"
        when 403
          "Permission Denied"
        when 401
          "Unauthenticated"
        when 501
          "Unimplemented"
        else
          "An Error Occurred"
    @template = 'error-loggedin' if @loggedInUser?
