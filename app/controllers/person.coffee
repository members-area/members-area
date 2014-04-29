LoggedInController = require './logged-in'
_ = require 'underscore'
async = require 'async'

module.exports = class PersonController extends LoggedInController
  @before 'setAdmin'
  @before 'getUsers', only: ['index']
  @before 'getClassNames', only: ['index']
  @before 'getUser', only: ['view']

  activeNavigationId: "person-index"

  index: ->

  view: ->

  getUsers: (done) ->
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

  getClassNames: (done) ->
    @isAdmin = @req.user.can 'admin'
    for user in @users
      classNames = []
      if @isAdmin
        classNames.push "unverified" unless user.verified
        classNames.push "unapproved" unless _.pluck(user.activeRoleUsers, 'role_id').indexOf(1) >= 0
      user.classNames = classNames.join ' '
    done()

  getUser: (done) ->
    @req.models.User.get @req.params.id, (err, @user) =>
      done(err)

  setAdmin: ->
    @admin = @loggedInUser.can 'admin'
