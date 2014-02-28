Controller = require '../controller'

module.exports = class AdminController extends Controller
  @before 'requireRoot'

  constructor: ->
    super

  settings: (done) ->
    if @req.method is 'GET'
      @data.email = @app.emailSetting.meta.settings
      done()
    else
      if typeof @data.email is 'object'
        @app.emailSetting.setMeta {settings: @data.email}
        @app.emailSetting.save done
      else
        @data.email = @app.emailSetting.meta.settings
        done()

  requireRoot: ->
    @redirectTo "/" unless @req.user?.can 'root'
