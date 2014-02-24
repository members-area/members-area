GitHubStrategy = require('passport-github').Strategy
FacebookStrategy = require('passport-facebook').Strategy
TwitterStrategy = require('passport-twitter').Strategy

module.exports = (done) ->
  passport = require "#{@app.path}/app/lib/passport"
  env = require "#{@app.path}/app/env"
  app = @app

  @hook 'navigation_items', ({addItem}) ->
    addItem 'user',
      title: 'Accounts'
      id: 'passport-passport-accounts'
      href: '/accounts'
      priority: 20

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

  ###*
   * GitHub Auth
  ###

  if env.GITHUB_ID and env.GITHUB_SECRET
    passport.use new GitHubStrategy(
      clientID: env.GITHUB_ID
      clientSecret: env.GITHUB_SECRET
      callbackURL: env.SERVER_ADDRESS + '/auth/github/callback'
    , (accessToken, refreshToken, profile, done) ->
      done null, profile
    )
    app.get '/auth/github', passport.authenticate('github')
    app.get '/auth/github/callback', passport.authenticate('github'), auth.socialProvider('github')

  ###*
   * Facebook Auth
  ###

  if env.FACEBOOK_ID and env.FACEBOOK_SECRET
    passport.use new FacebookStrategy(
      clientID: env.FACEBOOK_ID
      clientSecret: env.FACEBOOK_SECRET
      callbackURL: env.SERVER_ADDRESS + '/auth/facebook/callback'
    , (accessToken, refreshToken, profile, done) ->
        done null, profile
    )
    app.get '/auth/facebook', passport.authenticate('facebook')
    app.get '/auth/facebook/callback', passport.authenticate('facebook'), auth.socialProvider('facebook')

  ###*
   * Twitter Auth
  ###

  if env.TWITTER_KEY and env.TWITTER_SECRET
    passport.use new TwitterStrategy(
      consumerKey: env.TWITTER_KEY
      consumerSecret: env.TWITTER_SECRET
      callbackURL: env.SERVER_ADDRESS + "/auth/twitter/callback"
    , (token, tokenSecret, profile, done) ->
      done null, profile
    )
    app.get '/auth/twitter', passport.authenticate('twitter')
    app.get '/auth/twitter/callback', passport.authenticate('twitter'), auth.socialProvider('twitter')

  done()
