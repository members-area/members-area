LoggedInController = require './logged-in'
passport = require '../lib/passport'

module.exports = class UserController extends LoggedInController
  dashboard: ->
  account: (done) ->
    if @req.method is 'POST'
      # Process it
      @loggedInUser.address = String @req.body.address
      @loggedInUser.address = null if @loggedInUser.address.length is 0
      @loggedInUser.fullname = String @req.body.fullname
      @loggedInUser.save (e) =>
        if e
          console.dir e
          @error = e.message
        else
          @success = true
        done()
    else
      @data = @req.user
      done()
