###*
 * Provides Authentication Strategies. Exports the Passport.js
 * (http://passportjs.org/) object
###

###*
 * Module Dependencies
###

passport = require 'passport'
models = require './models'
env = require './env'
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
  req.models.User.find().where({username: username}).run (err, users) ->
    return done err if err
    [user] = users
    user.checkPassword password, (err, correct) ->
      return done err, correct if err or !correct
      return done null, user

###*
 * Exports
###

module.exports = passport
