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

    password:
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
    hooks: db.applyCommonHooks {}
    methods:
      hasActiveRole: (roleId, callback) ->
        roleId = roleId.id if typeof roleId is 'object'
        @getRoleUsers {where: ["id = ? AND rejected IS NULL AND accepted IS NOT NULL", roleId]}, (err, roles) ->
          callback (err || roles?.length < 1)

      getActiveRoles: ->
        promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
          models.RoleUser.findAll(
            where: ["approved IS NOT NULL AND rejected IS NULL AND UserId = ?", @id]
          ).done (err, roleUsers) =>
            return emitter.emit 'error', err if err
            roles = []
            for roleUser in roleUsers
              role = models.Role.getById(roleUser.RoleId)
              roles.push role if role
            emitter.emit 'success', roles
        return promise.run()

      requestRoles: (roles, options = {}) ->
        promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
          user = @
          request = (role, done) ->
            data =
              UserId: user.id
              RoleId: role.id
            models.RoleUser.create(data, options).done (err) ->
              done err

          async.mapSeries roles, request, (err, result) ->
            return emitter.emit 'error', err if err
            emitter.emit 'success'
        return promise.run()

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
      password: [
        orm.enforce.security.password('8', 'Must contain at least 8 characters.')
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
