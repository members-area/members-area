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
    instanceMethods:
      checkRequirement: (requirement, callback) ->
        models = require('./')
        switch requirement.type
          when 'text'
            process.nextTick callback
          when 'role'
            # models.User.find(@UserId).done
            @getUser().done (err, user) =>
              return callback "Error #{err} #{@UserId} #{user}" if err or !user?
              user.hasActiveRole models.Role.getById(requirement.roleId), (hasRole) ->
                return callback "Nope" unless hasRole
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
