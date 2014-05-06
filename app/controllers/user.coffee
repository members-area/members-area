LoggedInController = require './logged-in'
passport = require '../lib/passport'

module.exports = class UserController extends LoggedInController
  @before 'getPendingRoles', only: 'dashboard'

  dashboard: ->

  account: (done) ->
    if @req.method is 'POST'
      # XXX: Add old password verification
      if @req.body.password?.length
        if @req.body.password != @req.body.password2
          @error = "Passwords do not match"
          return done()
        else
          @loggedInUser.password = String @req.body.password
      @loggedInUser.address = String @req.body.address
      @loggedInUser.address = null if @loggedInUser.address.length is 0
      @loggedInUser.fullname = String @req.body.fullname
      @loggedInUser.save (e) =>
        if e
          @error = e
        else
          @success = true
        done()
    else
      @data = @req.user
      done()

  getPendingRoles: (done) ->
    @req.models.RoleUser.find(user_id:@loggedInUser.id)
      .where("approved IS NULL and rejected IS NULL")
      .all (err, @pendingRoleUsers = []) =>
        return done err if err
        done()
