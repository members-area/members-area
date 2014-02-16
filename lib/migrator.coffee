fs = require 'fs'
url = require 'url'
MigrationTask = require 'migrate-orm2'
orm = require 'orm'
require '../env'

exports.runMigration = (operation, arg, done = ->) ->
  {DATABASE_URL} = process.env
  orm.settings.set 'connection.debug', true
  orm.connect DATABASE_URL, (err, connection) ->
    throw err if err
    connection.on 'error', (err) ->
      console.error err.stack
      process.exit 1
    migrationTask = new MigrationTask connection.driver,
      dir: 'db/migrations'
      coffee: true
    migrationTask[operation] arg, (err) ->
      connection.close ->
        done err
