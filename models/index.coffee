fs = require 'fs'
Sequelize = require 'sequelize'
_ = require 'underscore'
config = require '../config/config.json'

sequelize = new Sequelize config.database, config.username, config.password, _.defaults config,
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
