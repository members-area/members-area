GitHubStrategy = require('passport-github').Strategy
FacebookStrategy = require('passport-facebook').Strategy
TwitterStrategy = require('passport-twitter').Strategy

module.exports =
  initialize: (done) ->
    passport = require "#{@app.path}/app/lib/passport"
    env = require "#{@app.path}/app/env"
    app = @app

    app.addRoute 'all', '/accounts', 'passport#passport#accounts'
    app.addRoute 'all', '/settings/passport', 'passport#passport#settings'

    @hook 'navigation_items', ({addItem}) ->
      addItem 'user',
        title: 'Accounts'
        id: 'passport-passport-accounts'
        href: '/accounts'
        priority: 20
      addItem 'settings',
        title: 'Social login'
        id: 'passport-passport-settings'
        href: '/settings/passport'
        priority: 100
        permissions: ['configure_passport']

    @hook 'render-session-login', (options, done) ->
      {controller, html} = options
      htmlToAdd = "
        <span>With: </span><br />
        <a class='register' href='/auth/facebook'>Facebook</a> |
        <a class='register' href='/auth/github'>GitHub</a> |
        <a class='register' href='/auth/twitter'>Twitter</a><br />
        "
      options.html = html.replace("</h2>", "</h2>"+htmlToAdd)

      done()

    socialProvider = (socialProvider, req, profile, done) ->
      req.models.UserLinked.find()
      .where(type:socialProvider,identifier:String(profile.id))
      .first (err, userLinked) ->
        if userLinked?
          userLinked.getUser done
        else if req.user
          data =
            type: socialProvider
            identifier: String(profile.id)
            user_id: req.user.id
          req.models.UserLinked.create data, (err, userLinked) ->
            userLinked.getUser done
        else
          # XXX: Better error message
          return done new Error("Unrecognised and no account")

    loggedin = -> (req, res, next) ->
      res.redirect "/"

    ###*
     * GitHub Auth
    ###

    supportedProviders = @supportedProviders()
    settings = @get()
    if supportedProviders.github
      passport.use new GitHubStrategy(
        clientID: settings.GITHUB_APP_ID
        clientSecret: settings.GITHUB_SECRET
        callbackURL: env.SERVER_ADDRESS + '/auth/github/callback'
        passReqToCallback: true
      , (req, accessToken, refreshToken, profile, done) ->
        socialProvider('github', req, profile, done)
      )
      app.get '/auth/github', passport.authenticate('github')
      app.get '/auth/github/callback', passport.authenticate('github'), loggedin()

    ###*
     * Facebook Auth
    ###

    if supportedProviders.facebook
      passport.use new FacebookStrategy(
        clientID: settings.FACEBOOK_APP_ID
        clientSecret: settings.FACEBOOK_SECRET
        callbackURL: env.SERVER_ADDRESS + '/auth/facebook/callback'
        passReqToCallback: true
      , (req, accessToken, refreshToken, profile, done) ->
        socialProvider('facebook', req, profile, done)
      )
      app.get '/auth/facebook', passport.authenticate('facebook')
      app.get '/auth/facebook/callback', passport.authenticate('facebook'), loggedin()

    ###*
     * Twitter Auth
    ###

    if supportedProviders.twitter
      passport.use new TwitterStrategy(
        consumerKey: settings.TWITTER_APP_ID
        consumerSecret: settings.TWITTER_SECRET
        callbackURL: env.SERVER_ADDRESS + "/auth/twitter/callback"
        passReqToCallback: true
      , (req, token, tokenSecret, profile, done) ->
        socialProvider('twitter', req, profile, done)
      )
      app.get '/auth/twitter', passport.authenticate('twitter')
      app.get '/auth/twitter/callback', passport.authenticate('twitter'), loggedin()

    done()

  supportedProviders: ->
    settings = @get()
    providers =
      github: settings.GITHUB_APP_ID and settings.GITHUB_SECRET
      facebook: settings.FACEBOOK_APP_ID and settings.FACEBOOK_SECRET
      twitter: settings.TWITTER_APP_ID and settings.TWITTER_SECRET
    return providers
