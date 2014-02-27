Controller = require '../../../app/controller'

module.exports = class PassportController extends Controller
  settings: (done) ->
    @data = @plugin.get() if @req.method is 'GET'
    return done() if @req.method isnt 'POST'
    console.dir @data
    @plugin.set @data, (err) =>
      @app.restartRequired = true
      done()
