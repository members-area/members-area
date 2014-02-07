{User} = require __dirname+'/../models'

module.exports =
  up: (migration, DataTypes, done) ->
    migration.createTable(User.tableName, User.rawAttributes).complete(done)

  down: (migration, DataTypes, done) ->
    migration.dropTable(User.tableName).complete(done)
