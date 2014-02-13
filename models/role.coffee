Sequelize = require 'sequelize'

module.exports = (sequelize, DataTypes) ->
  return sequelize.define 'Role',
    name:
      type: DataTypes.STRING
      allowNull: false
      unique: true
      validate:
        isAlphanumeric: true

    meta: sequelize.membersMeta
  ,
    classMethods:
      seedData: [
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
      loadAll: ->
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
      getById: (id) ->
        @roles ?= []
        return role for role in @roles when role.id is id
        return null
