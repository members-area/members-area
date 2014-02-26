module.exports = (db, models) ->
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

  Role.modelName = 'Role'
  return Role