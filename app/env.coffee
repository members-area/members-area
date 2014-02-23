url = require 'url'
orm = require 'orm'

# Make sure we're in the right folder.
process.chdir __dirname

process.env.NODE_ENV ?= 'development'
process.env.DATABASE_URL ?= require('../config/db.json')[process.env.NODE_ENV]

unless process.env.DATABASE_URL
  console.error "No DATABASE_URL - exiting."
  process.exit 1

# Fix SQLite
parsed = url.parse process.env.DATABASE_URL
if parsed.protocol is 'sqlite:'
  orm.settings.set 'connection.reconnect', false
  path = "#{__dirname}/../#{parsed.pathname.substr(1)}"
  process.env.DATABASE_URL = "sqlite://#{path}"

module.exports = process.env
