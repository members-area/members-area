async = require 'async'
models = require('./')

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'RoleUser',
    approved:
      type: DataTypes.DATE
      allowNull: true

    rejected:
      type: DataTypes.DATE
      allowNull: true

    rejectionReason:
      type: DataTypes.TEXT
      allowNull: true

    meta: sequelize.membersMeta
  ,
    tableName: 'RolesUsers'

    hooks:
      beforeCreate: (roleUser, next) ->
        return next() if roleUser.approved?
        role = models.Role.getById(roleUser.id)
        userId = roleUser.id
        if userId is 1 and role in [role.base, role.owner]
          roleUser.approved = new Date()
          return next()
        # Should we auto-grant this role?
        roleUser.shouldAutoApprove (autoApprove) =>
          if autoApprove
            roleUser.approved = new Date()
          next()

    instanceMethods:
      shouldAutoApprove: (callback) ->
        role = models.Role.getById(@RoleId)
        return callback new Error("Not found") unless role
        requirements = role.meta.requirements ? []
        async.map requirements, @checkRequirement.bind(this), (err) ->
          callback !err

      checkRequirement: (requirement, callback) ->
        models = require('./')
        switch requirement.type
          when 'text'
            process.nextTick callback
          when 'role'
            # models.User.find(@UserId).done
            @getUser().done (err, user) =>
              return callback "Error #{err} #{@UserId} #{user}" if err or !user?
              user.hasActiveRole(models.Role.getById(requirement.roleId)).done (err, hasRole = false) ->
                return callback new Error "Nope" unless hasRole
                callback()
          when 'approval'
            {roleId, count} = requirement
            approvals = @meta.approvals
            approvals ?= []
            count-- for approval in approvals when approval.roleId is roleId
            process.nextTick ->
              return callback "#{count} more approvals for role '#{roleId}' required" if count > 0
              callback()
          else
            console.error "Requirement type '#{requirement.type}' not known."
            process.nextTick ->
              callback "Unknown"
