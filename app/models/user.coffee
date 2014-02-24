async = require 'async'
bcrypt = require 'bcrypt'
orm = require 'orm'

disallowedUsernameRegexps = [
  /master$/i
  /^admin/i
  /admin$/i
  /^(southackton|soha|somakeit|smi)$/i
  /^trust/i
  /^director/i
  /^(root|daemon|bin|sys|sync|backup|games|man|lp|mail|news|proxy|www-data|apache|apache2|irc|nobody|syslog|sshd|ubuntu|mysql|logcheck|redis)$/i
  /^(admin|join|social|info|queries)$/i
]

module.exports = (db, models) ->
  User = db.define 'user', {
    id:
      type: 'number'
      serial: true
      primary: true

    email:
      type: 'text'
      required: true

    username:
      type: 'text'
      required: true

    hashed_password:
      type: 'text'
      required: true

    paidUntil:
      type: 'date'
      required: false
      time: false

    fullname:
      type: 'text'
      required: false

    address:
      type: 'text'
      required: false

    verified:
      type: 'date'
      required: false
      time: true

    meta:
      type: 'object'
      required: true
      defaultValue: {}
  },
    timestamp: true
    hooks: db.applyCommonHooks
      beforeValidation: (done) ->
        if @password?
          bcrypt.hash @password, 10, (err, hash) =>
            return done err if err
            delete @password
            @hashed_password = hash
            done()
        else
          done()
      afterAutoFetch: (done) ->
        # Find active roles
        return done() unless @isPersisted()
        @getRoleUsers().where("approved IS NOT NULL AND rejected IS NULL", []).run (err, @activeRoleUsers) =>
          done(err)
    methods:
      checkPassword: (password, callback) ->
        bcrypt.compare password, @hashed_password, callback

      hasActiveRole: (roleId, callback) ->
        roleId = roleId.id if typeof roleId is 'object'
        @getRoleUsers()
        .where("id = ? AND rejected IS NULL AND accepted IS NOT NULL", [roleId])
        .run (err, roles) ->
          callback (err || roles?.length < 1)

      getActiveRoles: (callback) ->
        models.RoleUser.find()
        .where("approved IS NOT NULL AND rejected IS NULL AND user_id = ?", [@id])
        .run (err, roleUsers) =>
          return callback err if err
          roleIds = (roleUser.role_id for roleUser in roleUsers)
          if roleIds.length
            models.Role.find {id:roleIds}, callback
          else
            callback null, []

      requestRoles: (roles, callback) ->
        user_id = @id
        request = (role_id, done) ->
          # XXX: prevent requesting the same role twice
          role_id = role_id.id if typeof role_id is 'object'
          data =
            user_id: user_id
            role_id: role_id
          models.RoleUser.create data, done

        async.mapSeries roles, request, (err, result) ->
          return callback err if err
          callback()

      can: (permissions) ->
        permissions = [permissions] unless Array.isArray permissions
        for permission in permissions when permission?.length
          found = false
          for activeRoleUser in @activeRoleUsers
            if permission in activeRoleUser.meta.grants
              found = true
              break
          return false unless found
        return true

    validations:
      email: [
        orm.enforce.patterns.email()
      ]
      username: [
        orm.enforce.ranges.length(3, 14, "Must be between 3 and 14 characters")
        orm.enforce.patterns.match(/^[a-z]/i, null, "Must start with a letter")
        orm.enforce.patterns.match(/^[a-z0-9]*$/i, null, "Must be alphanumeric")
        orm.enforce.lists.outside(disallowedUsernameRegexps, "Disallowed username")
      ]
      fullname: [
        orm.enforce.patterns.match(/.+ .+$/, "Invalid full name")
      ]
      address: [
        orm.enforce.ranges.length(8, undefined, "Too short")
        orm.enforce.patterns.match(/(\n|,)/, null, "Must have multiple lines")
        orm.enforce.patterns.match(/(GIR 0AA)|((([A-Z][0-9][0-9]?)|(([A-Z][A-Z][0-9][0-9]?)|(([A-Z][0-9][A-HJKSTUW])|([A-Z][A-Z][0-9][ABEHMNPRVWXY])))) ?[0-9][A-Z]{2})/i, null, "Must have a valid postcode")
      ]

  User.modelName = 'User'
  return User
