fs = require 'fs'
url = require 'url'
MigrationTask = require 'migrate-orm2'
orm = require 'orm'
path = require 'path'
require '../env'

exports.runMigration = (operation, arg, pluginName, done) ->
  dir = path.resolve "#{__dirname}/../../db/migrations"
  if typeof pluginName is 'function'
    done = pluginName
    pluginName = null
  tableName = "orm_migrations"
  if pluginName?
    Plugin = require '../plugin'
    plugin = Plugin.load pluginName
    dir = "#{plugin.path}/db/migrations"
    suffix = pluginName.replace(/[^a-z]/g, "_").toLowerCase()
    tableName += "_#{suffix}"
  fs.exists dir, (exists) ->
    return done() unless exists
    {DATABASE_URL} = process.env
    orm.connect DATABASE_URL, (err, connection) ->
      throw err if err
      connection.on 'error', (err) ->
        console.error err.stack
        process.exit 1
      migrationTask = new MigrationTask connection.driver,
        dir: dir
        tableName: tableName
        coffee: true
      migrationTask[operation] arg, (err) ->
        connection.close ->
          done? err
