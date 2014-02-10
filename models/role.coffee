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
      loadAll: (callback) ->
        @findAll().complete (err, roles) ->
          return callback err if err
          return callback new Error("No roles") unless roles?.length
          roles.base = null
          roles.owner = null
          for role in roles ? []
            if role.meta.base
              roles.base ?= role
            else if role.meta.owner
              roles.owner ?= role
          return callback new Error("No base role") unless roles.base
          return callback new Error("No owner role") unless roles.owner
          return callback null, roles
