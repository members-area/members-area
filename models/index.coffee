fs = require 'fs'
Sequelize = require 'sequelize'

{DB_HOST, DB_DATABASE, DB_USERNAME, DB_PASSWORD, DB_DRIVER, SQLITE_PATH} = require '../env'

sequelize = new Sequelize DB_DATABASE, DB_USERNAME, DB_PASSWORD,
  host: DB_HOST
  dialect: DB_DRIVER
  storage: SQLITE_PATH ? './db.sqlite'
  define:
    charset: 'utf8'
    collate: 'utf8_general_ci'

m = module.exports
m.sequelize = sequelize

fs.readdirSync(__dirname).forEach (filename) ->
  [ignore, name, ext] = filename.match /^(.*?)(?:\.(js|coffee))?$/
  return if name is 'index' or name.substr(0,1) is '.'
  model = sequelize.import "#{__dirname}/#{name}"
  m[model.name] = model
