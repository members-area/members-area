async = require 'async'

module.exports = (db, models, app) ->
  Role = db.define 'role', {
    id:
      type: 'number'
      serial: true
      primary: true

    name:
      type: 'text'
      required: true

    meta:
      type: 'object'
      required: true
      defaultValue: {}
  },
    timestamp: true
    hooks: db.applyCommonHooks {}
    methods:
      canApply: (user, callback) ->
        requirements = @meta.requirements ? []

        canApplyForRequirement = (requirement, next) ->
          canApply = true
          if requirement.type is 'role'
            canApply = requirement.roleId in user.activeRoleIds
          return next() if canApply
          next new Error("Don't have required role")

        async.map requirements, canApplyForRequirement, (err) ->
          callback !err

    _validations:
      name:
        isAlphanumeric: true

  Role.seedData = [
    {
      id: 1
      name: "Registered"
      meta:
        base: true
        grants: ['usage']
    }
    {
      id: 2
      name: "Owner"
      meta:
        owner: true
    }
  ]

  Role.generateRequirementTypes = (callback) ->
    Role.find (err, roles) ->
      return callback err if err
      roleOptions = ({value: role.id, label: role.name} for role in roles)
      roleValidator = (value) ->
        value = parseInt(value, 10)
        throw new Error("Invalid roleId") unless isFinite(value)
        for role in roles
          return role.id if role.id is value
        throw new Error("Non-existent roleId")

      requirementTypes = [
        {
          type: 'text'
          title: "Text instruction"
          getSentence: (data) ->
            data.text
          inputs: [
            {
              label: "Instruction"
              type: "text"
              name: "text"
            }
          ]
        }
        {
          type: 'approval'
          title: 'Approvals'
          getSentence: (data) ->
            roleName = data.roleId
            roleName = role.name for role in roles when role.id is data.roleId
            "Must be approved by #{data.count} #{roleName}s"
          inputs: [
            {
              label: "Role"
              type: "select"
              name: "roleId"
              options: roleOptions
              validator: roleValidator
            }
            {
              label: "Number of approvals"
              type: "text"
              name: "count"
              value: "1"
              validator: (value) ->
                value = parseInt(value, 10)
                throw new Error("Invalid count") unless isFinite(value) and value > 0
                return value
            }
          ]
        }
        {
          type: 'role'
          title: 'Must hold role'
          getSentence: (data) ->
            roleName = data.roleId
            roleName = role.name for role in roles when role.id is data.roleId
            "Must hold the '#{roleName}' role."
          inputs: [
            {
              label: "Role"
              type: "select"
              name: "roleId"
              options: roleOptions
              validator: roleValidator
            }
          ]
        }
      ]

      app.pluginHook 'requirement_types', {requirementTypes}, =>
        object = {}
        object[requirementType.type] = requirementType for requirementType in requirementTypes
        callback(null, object)

  Role.modelName = 'Role'
  return Role
