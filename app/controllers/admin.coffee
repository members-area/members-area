Controller = require '../controller'
async = require 'async'

module.exports = class AdminController extends Controller
  @before 'requireRoot'

  constructor: ->
    super

  settings: (done) ->
    @themes = ({name: plugin.name, value: plugin.identifier} for plugin in @app.plugins when plugin.themeMiddleware?)
    @themes.unshift {name: "Default", value: ""}
    next = (err) =>
      return done err if err
      @data.email = @app.emailSetting.meta.settings
      @data.theme = @app.themeSetting?.meta.settings ? {}
      done()
    if @req.method is 'GET'
      next()
    else
      async.series
        email: (next) =>
          if typeof @data.email is 'object'
            @app.emailSetting.setMeta {settings: @data.email}
            @app.emailSetting.save (err) =>
              @app.updateEmailTransport()
              next err
          else
            next()
        theme: (next) =>
          if typeof @data.theme is 'object'
            @app.themeSetting.setMeta {settings: @data.theme}
            @app.themeSetting.save next
          else
            next()
      , (err) =>
        return next err if err
        # Make the page load fresh
        @redirectTo "/settings", status: 303

  requireRoot: ->
    @redirectTo "/" unless @req.user?.can 'root'
