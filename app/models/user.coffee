async = require 'async'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
juice = require 'juice'
htmlToText = require 'html-to-text'
orm = require 'orm'
_ = require 'underscore'

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

module.exports = (db, models, app) ->
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
      afterCreate: (created) ->
        done = ->
        return done() if !created and !@id
        if @id is 1
          @verified = new Date()
          @save done
        else
          @sendVerificationMail()
          done()
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
          @activeRoleIds = _.pluck @activeRoleUsers, 'role_id'
          done(err)
    methods:
      verify: (code, done) ->
        return done() if @verified
        verificationCode = @meta.emailVerificationCode
        if code is verificationCode
          delete @meta.emailVerificationCode
          @verified = new Date()
          @save done
        else
          # XXX: limit attempts
          err = new Error "Incorrect verification code"
          done err

      sendVerificationMail: (done) ->
        done ?= (err) ->
          console.error err if err?
        next = =>
          code = @meta.emailVerificationCode
          verifyURL = "#{process.env.SERVER_ADDRESS}/verify?id=#{@id}&code=#{encodeURIComponent code}"
          locals =
            user: @
            email: @email
            code: code
            verifyURL: verifyURL
          app.render "emails/verification", locals, (err, html) =>
            return done err if err
            options =
              url: process.env.SERVER_ADDRESS
            juice.juiceContent html, options, (err, html) =>
              return done err if err
              mailOptions =
                from: app.emailSetting.meta.settings.from_address ? "members-area@example.com"
                to: "#{@fullname} <#{@email}>"
                subject: "Email Verification"
                html: html
                text: htmlToText.fromString(html, tables: true)
              app.mailTransport.sendMail mailOptions, done
        unless @meta.emailVerificationCode
          crypto.randomBytes 8, (err, bytes) =>
            @setMeta emailVerificationCode: bytes.toString('hex')
            @save next
        else
          next()

      checkPassword: (password, callback) ->
        bcrypt.compare password, @hashed_password, callback

      hasActiveRole: (roleId, callback) ->
        roleId = roleId.id if typeof roleId is 'object'
        @getRoleUsers()
        .where("role_id = ? AND rejected IS NULL AND approved IS NOT NULL", [roleId])
        .run (err, roles) ->
          callback (!err && roles?.length > 0)

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
            if activeRoleUser.role.meta.owner or permission in (activeRoleUser.role.meta.grants ? [])
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
        orm.enforce.patterns.match(/.+ .+$/, null, "Invalid full name")
      ]
      address: [
        orm.enforce.ranges.length(8, undefined, "Too short")
        orm.enforce.patterns.match(/(\n|,)/, null, "Must have multiple lines")
        orm.enforce.patterns.match(/(GIR 0AA)|((([A-Z][0-9][0-9]?)|(([A-Z][A-Z][0-9][0-9]?)|(([A-Z][0-9][A-HJKSTUW])|([A-Z][A-Z][0-9][ABEHMNPRVWXY])))) ?[0-9][A-Z]{2})/i, null, "Must have a valid postcode")
      ]

  User.modelName = 'User'
  return User
