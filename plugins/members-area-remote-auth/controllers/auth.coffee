Controller = require 'members-area/app/controller'

module.exports = class AuthController extends Controller
  me: (done) ->
    @rendered = true # We're handling rendering
    unless @req.body.email or @req.body.username
      @res.json 400, {errorCode: 400, errorMessage: "No email/username provided"}
      return done()
    unless @req.body.password
      @res.json 400, {errorCode: 400, errorMessage: "No password provided"}
      return done()
    where = {}
    password = @req.body.password
    if @req.body.email?.match /@/ # Legacy username as email support
      where = email: @req.body.email
    else
      where = username: @req.body.username ? @req.body.email
    @req.models.User.find()
    .where(where)
    .first (err, user) =>
      fail = =>
        @res.json 404, {errorCode: 404, errorMessage: "Username or password do not match an existing approved account."}
        done()
      success = =>
        @res.json 200, {id: user.id, username: user.username, email: user.email}
        done()
      return fail() if err
      return fail() unless user
      user.hasActiveRole 1, (approved) =>
        return fail() unless approved
        user.checkPassword @req.body.password, (err, correct) =>
          return fail() unless correct and !err
          return success()
