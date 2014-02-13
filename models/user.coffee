Sequelize = require 'sequelize'
async = require 'async'
bcrypt = require 'bcrypt'
models = require './'

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

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'User',
    email:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        isEmail: true

    username:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        len: {args: [3,14], msg: "Must be between 3 and 14 characters"}
        isAlphanumeric: (value) -> throw "Must be alphanumeric" unless /^[a-z0-9]*$/i.test value
        startsWithLetter: (value) -> throw "Must start with a letter" unless /^[a-z]/i.test value
        isDisallowed: (value) -> throw "Disallowed username" for regexp in disallowedUsernameRegexps when regexp.test value

    password:
      type: DataTypes.STRING
      allowNull: false
      validate:
        len: {args: [6, 9999], msg: "Must be at least 6 characters"}

    paidUntil:
      type: DataTypes.DATE
      allowNull: true

    fullname:
      type: DataTypes.STRING
      allowNull: true
      validate:
        isName: (value) -> throw "Invalid name" unless /^.+ .+$/.test value

    address:
      type: DataTypes.TEXT
      allowNull: true
      validate:
        len: {args: [8, 999], msg: "Too short"}
        hasMultipleLines: (value) -> throw "Must have multiple lines" unless /(\n|,)/.test(value)
        hasPostcode: (value) -> throw "Must have valid postcode" unless /(GIR 0AA)|((([A-Z][0-9][0-9]?)|(([A-Z][A-Z][0-9][0-9]?)|(([A-Z][0-9][A-HJKSTUW])|([A-Z][A-Z][0-9][ABEHMNPRVWXY])))) ?[0-9][A-Z]{2})/i.test(value)

    verified:
      type: DataTypes.DATE
      allowNull: true

    meta: sequelize.membersMeta
  ,
    validate:
      addressRequired: -> # XXX: if they've a role that requires address, don't allow address to be null, etc.
    instanceMethods:
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
