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

    createdAt:
      type: 'date'
      required: true
      time: true
      defaultValue: -> new Date()

    updatedAt:
      type: 'date'
      required: true
      time: true
      defaultValue: -> new Date()
  },
    hooks: db.applyCommonHooks {}
    _validations:
      name:
        isAlphanumeric: true

  Role.seedData = [
    {
      name: "Registered"
      meta:
        base: true
        grants: ['usage']
    }
    {
      name: "Owner"
      meta:
        owner: true
    }
  ]

  Role.loadAll = ->
    promise = new Sequelize.Utils.CustomEventEmitter (emitter) =>
      @findAll().complete (err, roles) =>
        return emitter.emit 'error', err if err
        return emitter.emit 'error', new Error("No roles") unless roles?.length
        roles.base = null
        roles.owner = null
        for role in roles ? []
          if role.meta.base
            roles.base ?= role
          else if role.meta.owner
            roles.owner ?= role
        return emitter.emit 'error', new Error("No base role") unless roles.base
        return emitter.emit 'error', new Error("No owner role") unless roles.owner
        @roles = roles
        return emitter.emit 'success', @roles
    return promise.run()

  Role.getById = (id) ->
    @roles ?= []
    return role for role in @roles when role.id is id
    return null

  Role.modelName = 'Role'
  return Role
