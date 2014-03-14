LoggedInController = require './logged-in'
_ = require 'underscore'
async = require 'async'

module.exports = class PersonController extends LoggedInController
  activeNavigationId: "person-index"
  index: (done) ->
    async.series
      getUsers: (done) =>
        @isAdmin = @req.user.can 'admin'
        clause =
          if @isAdmin
            null
          else
            "verified IS NOT NULL"
        @req.models.User.find()
        .where(clause)
        .run (err, @users) =>
          done(err)
      getClassNames: (done) =>
        for user in @users
          classNames = []
          classNames.push "unverified" unless user.verified
          classNames.push "unapproved" unless _.pluck(user.activeRoleUsers, 'role_id').indexOf(1) >= 0
          # XXX: if @req.user.can 'admin' then add payment classes
          user.classNames = classNames.join ' '
        done()
    , (err) =>
      return done err if err
      done()

  view: (done) ->
    @req.models.User.get @req.params.id, (err, @user) =>
      done(err)
