LoggedInController = require './logged-in'
_ = require 'underscore'
async = require 'async'
csv = require 'csv'

module.exports = class PersonController extends LoggedInController
  @before 'setAdmin'
  @before 'ensureAdmin', only: ['export']
  @before 'getUsers', only: ['index', 'export']
  @before 'getClassNames', only: ['index']
  @before 'getStats', only: ['index']
  @before 'getUser', only: ['view']
  @before 'loadRoles', only: ['export']

  activeNavigationId: "person-index"

  index: ->

  view: ->

  export: (done) ->
    headers = {
      Email: 'email'
      Name: 'fullname'
      Username: 'username'
      Address: 'address'
      Verified: (u) -> if u.verified then "Y" else ""
    }
    for role in @roles then do (role) ->
      headers[role.name] = (user) ->
        if role.id in user.activeRoleIds
          "Y"
        else
          ""

    rows =
      for user in @users
        row = {}
        for header, source of headers
          row[header] =
            if typeof source is 'string'
              user[source]
            else
              source(user)
        row

    csvOptions =
      header: true
    csv.stringify rows, csvOptions, (err, res) =>
      return done(err) if err
      @res.set 'Content-Type', 'text/csv'
      @res.send 200, res
      @rendered = true # We're handling rendering
      return done()
    return

  getUsers: (done) ->
    @isAdmin = @req.user.can 'admin'
    clause =
      if @isAdmin
        null
      else
        "verified IS NOT NULL"
    @req.models.User.find({}, autoFetch: false)
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

  getStats: (done) ->
    roles = {}
    counts = {}
    for user in @users
      for roleUser in user.activeRoleUsers
        roles[roleUser.role.id] ?= roleUser.role
        counts[roleUser.role.id] ?= 0
        counts[roleUser.role.id]++
    @roleStats = []
    roleIds = Object.keys(roles).sort()
    for roleId in roleIds
      @roleStats.push
        role: roles[roleId]
        count: counts[roleId]
    done()

  getUser: (done) ->
    @req.models.User.get @req.params.id, (err, @user) =>
      done(err)

  setAdmin: ->
    @admin = @loggedInUser.can 'admin'

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)
