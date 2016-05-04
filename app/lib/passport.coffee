###*
 * Provides Authentication Strategies. Exports the Passport.js
 * (http://passportjs.org/) object
###

###*
 * Module Dependencies
###

passport = require 'passport'
LocalStrategy = require('passport-local').Strategy

###*
 * Shared Stragegy Helpers
###

passport.serializeUser = (user, done) ->
  done null, user.id

passport.deserializeUser = (id, req, done) ->
  req.models.User.get id, done

###*
 * Local Auth
###

passport.use new LocalStrategy {passReqToCallback: true}, (req, username, password, done) ->
  req.models.User.find().where("LOWER(username) = ?", [username.toLowerCase()]).first (err, user) ->
    return done err if err
    return done() unless user
    user.checkPassword password, (err, correct) ->
      return done err if err or !correct
      return done null, user

###*
 * Exports
###

module.exports = passport
