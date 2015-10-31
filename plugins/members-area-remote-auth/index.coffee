module.exports =
  initialize: (done) ->
    @app.addRoute 'all', '/me', 'members-area-remote-auth#auth#me'
    @app.addRoute 'all', '/api/user/auth', 'members-area-remote-auth#auth#me'
    done()
