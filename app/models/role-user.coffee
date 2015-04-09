async = require 'async'
_ = require 'underscore'
encode = require('entities').encodeXML

module.exports = (db, AllModels, app) ->
  RoleUser = db.define 'role_user', {
    id:
      type: 'number'
      serial: true
      primary: true

    role_id:
      type: 'number'
      required: true

    user_id:
      type: 'number'
      required: true

    approved:
      type: 'date'
      required: false

    rejected:
      type: 'date'
      required: false

    meta:
      type: 'object'
      required: true
      defaultValue: {}
  },
    timestamp: true
    hooks: db.applyCommonHooks
      beforeCreate: (next) ->
        return next() if @approved?
        @getRole (err, role) =>
          return next err if err
          userId = @user_id
          baseRoleId = 1
          ownerRoleId = 2
          if userId is 1 and role.id in [baseRoleId, ownerRoleId]
            @approved = new Date()
            return next()
          # Should we auto-grant this role?
          @_shouldAutoApprove (autoApprove) =>
            if autoApprove
              @approved = new Date()
            next()

      afterAutoFetch: (done) ->
        AllModels.Role.getCached @role_id, (err, @role) =>
          return done err if err
          @checkApproval done

    methods:
      approve: (user, requirementId, cb) ->
        callback = (err) =>
          console.warn "Approve #{@user_id} for #{@role_id} by #{user.id}[#{user.activeRoleIds.join(", ")}] error: #{err.message}" if err
          cb err
        requirementId = String(requirementId)
        @getRole (err, role) =>
          return callback err if err
          requirements = role.meta.requirements
          console.log requirements
          for requirement in requirements when requirementId is String(requirement.id)
            roleId = requirement.roleId
            return callback new Error "Permission denied" unless roleId in (user.activeRoleIds ? [])
            return callback new Error "Invalid roleId" unless roleId > 0
            approvals = @meta.approvals
            approvals ?= {}
            approvals[requirementId] ?= []
            if user.id not in approvals[requirementId]
              approvals[requirementId].push user.id
              @setMeta approvals:approvals
              @checkApproval =>
                @save callback
            else
              callback()
            return
          callback new Error "Requirement '#{requirementId}' not found"

      getRequirementsWithStatusForUser: (user, callback) ->
        next = (err, role) =>
          return callback err if err
          requirements = role.meta.requirements
          checkRequirement = (requirement, next) =>
            @_checkRequirement requirement, (err) =>
              passed = !err?
              actionable = false
              if requirement.type is 'approval' or (requirement.type is 'text' and requirement.roleId)
                if requirement.roleId in (user.activeRoleIds ? []) and user.id not in (@meta.approvals?[requirement.id] ? [])
                  actionable = true
              next null, _.extend requirement,
                passed: passed
                actionable: !passed and actionable
          async.map requirements, checkRequirement, callback
        return next(null, @role) if @role
        @getRole next

      checkApproval: (callback) ->
        return callback() if @approved?
        @_shouldAutoApprove (autoApprove) =>
          if autoApprove
            @approved = new Date()
            @save (err) =>
              return callback err if err
              @getUser (err, user) =>
                return callback err if err
                locals =
                  to: "#{user.fullname} <#{user.email}>"
                  subject: "Role Granted: #{@role.name}"
                  user: user
                  role: @role
                  site: app.siteSetting.meta.settings
                app.sendEmail "role-granted", locals, (err) =>
                  console.error err if err
                  callback()
          else
            callback()

      reject: (options, callback) ->
        return callback() if @rejected?
        return callback new Error "Who rejected?" unless options.userId
        @rejected = options.date ? new Date()
        @setMeta rejectedBy: options.userId
        if options.reason
          @setMeta rejectionReason: options.reason
        @save (err) =>
          return callback err if err
          @getUser (err, user) =>
            return callback err if err
            locals =
              to: "#{user.fullname} <#{user.email}>"
              subject: "#{if @approved then "Role Revoked" else "Application Rejected"}: #{@role.name}"
              user: user
              role: @role
              roleUser: @
              rejectionText: encode(@meta.rejectionReason ? "").replace(/\n/g, "<br>")
              site: app.siteSetting.meta.settings
            app.sendEmail "role-revoked", locals, (err) =>
              console.error err if err
              callback()

      _shouldAutoApprove: (callback) ->
        role = @role
        return callback false unless role
        requirements = role.meta.requirements ? []
        # I have no idea why, but using mapSeries instead of map here stops a segfault.
        async.mapSeries requirements, @_checkRequirement.bind(this), (err) ->
          callback !err

      _checkRequirement: (requirement, callback) ->
        switch requirement.type
          when 'text'
            if requirement.roleId and requirement.id
              approvals = @meta.approvals?[requirement.id]
              approvals ?= []
              count = requirement.count ? 1
              count -= approvals.length
              process.nextTick ->
                return callback "Requires approval for '#{requirement.text}' by someone with role '#{requirement.roleId}'" if count > 0
                callback()
            else
              # No role specified - approve
              process.nextTick callback
          when 'role'
            @getUser (err, user) =>
              return callback err if err
              return callback new Error "User not found" unless user?
              user.hasActiveRole requirement.roleId, (hasRole = false) ->
                return callback new Error "Nope" unless hasRole
                callback()
          when 'approval'
            {id, roleId, count} = requirement
            approvals = @meta.approvals?[id]
            approvals ?= []
            count -= approvals.length
            process.nextTick ->
              return callback "#{count} more approvals for role '#{roleId}' required" if count > 0
              callback()
          else
            console.error "Requirement type '#{requirement.type}' not known."
            process.nextTick ->
              callback "Unknown"

  RoleUser.modelName = 'RoleUser'
  return RoleUser
