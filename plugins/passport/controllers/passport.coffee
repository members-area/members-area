Controller = require '../../../app/controller'

module.exports = class PassportController extends Controller
  settings: (done) ->
    unless @req.user and @req.user.can('configure_passport')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    @data = @plugin.get() if @req.method is 'GET'
    return done() if @req.method isnt 'POST'
    console.dir @data
    @plugin.set @data, (err) =>
      @app.restartRequired = true
      done()

  accounts: (done) ->
    @supportedProviders = @plugin.supportedProviders()
    @req.models.UserLinked.find()
    .where({user_id:@req.user.id})
    .run (err, userLinkeds) =>
      @accounts = {}
      @accounts[userLinked.type] = true for userLinked in userLinkeds ? []
      done()
