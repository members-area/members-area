Controller = require '../controller'

class LoggedInController extends Controller
  @before 'requireLoggedIn'

  requireLoggedIn: ->
    @redirectTo "/login?next=#{encodeURIComponent @req.path}" unless @req.user?

module.exports = LoggedInController
