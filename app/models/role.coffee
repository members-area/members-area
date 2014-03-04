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
        callback(null, requirementTypes)

  Role.modelName = 'Role'
  return Role
