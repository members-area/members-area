Controller = require '../controller'
passport = require '../lib/passport'

module.exports = class SessionController extends Controller
  constructor: ->
    super
    @data[k] = null for k, v of @data when v is ""

  login: (done) ->
    @redirectTo "/" if @req.user?
    return done() unless @req.method is 'POST'
    handle = (err, user, info) =>
      return done err if err
      return done() unless user
      unless user.verified
        user.sendVerificationMail()
        @template = 'unverified'
        @email = user.email
        return done()
      user.hasActiveRole 1, (approved) =>
        if approved
          @req.login user, (err) =>
            return done err if err
            # XXX: check for and handle ?next
            @redirectTo "/", status: 303
        else
          @template = 'unapproved'
          done()
    passport.authenticate('local', handle)(@req, @res, @next)

  logout: ->
    @req.logout()
    @redirectTo "/", status: 303
