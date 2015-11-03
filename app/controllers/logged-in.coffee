Controller = require '../controller'

class LoggedInController extends Controller
  @before 'requireLoggedIn'

module.exports = LoggedInController
