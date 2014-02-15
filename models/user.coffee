async = require 'async'
bcrypt = require 'bcrypt'

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
      required: true
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

    createdAt:
      type: 'date'
      required: true
      time: true

    updatedAt:
      type: 'date'
      required: true
      time: true
  },
    _methods:
      hasActiveRole: (roleId) ->
        promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
          roleId = roleId.id if typeof roleId is 'object'
          @getRoles(where: ["id = ? AND rejected IS NULL AND accepted IS NOT NULL", roleId]).done (err, roles) ->
            return emitter.emit 'error', err if err
            emitter.emit 'success', (err || roles?.length < 1)
        return promise.run()

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

    _validations:
      email:
        isEmail: true
      username:
        len: {args: [3,14], msg: "Must be between 3 and 14 characters"}
        isAlphanumeric: (value) -> throw "Must be alphanumeric" unless /^[a-z0-9]*$/i.test value
        startsWithLetter: (value) -> throw "Must start with a letter" unless /^[a-z]/i.test value
        isDisallowed: (value) -> throw "Disallowed username" for regexp in disallowedUsernameRegexps when regexp.test value
      password:
        len: {args: [6, 9999], msg: "Must be at least 6 characters"}
      fullname:
        isName: (value) -> throw "Invalid name" unless /^.+ .+$/.test value
      address:
        len: {args: [8, 999], msg: "Too short"}
        hasMultipleLines: (value) -> throw "Must have multiple lines" unless /(\n|,)/.test(value)
        hasPostcode: (value) -> throw "Must have valid postcode" unless /(GIR 0AA)|((([A-Z][0-9][0-9]?)|(([A-Z][A-Z][0-9][0-9]?)|(([A-Z][0-9][A-HJKSTUW])|([A-Z][A-Z][0-9][ABEHMNPRVWXY])))) ?[0-9][A-Z]{2})/i.test(value)
        addressRequired: -> # XXX: if they've a role that requires address, don't allow address to be null, etc.

  User.modelName = 'User'
  return User
