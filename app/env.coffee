url = require 'url'
orm = require 'orm'

process.env.NODE_ENV ?= 'development'
process.env.DATABASE_URL ?= require("#{process.cwd()}/config/db.json")[process.env.NODE_ENV]

try
  config = require "#{process.cwd()}/config/#{process.env.NODE_ENV}.json"
  process.env.SERVER_ADDRESS ?= config.serverAddress
  process.env.SECRET ?= config.secret

unless process.env.DATABASE_URL
  console.error "No DATABASE_URL - exiting."
  process.exit 1

# Fix SQLite
parsed = url.parse process.env.DATABASE_URL
if parsed.protocol is 'sqlite:'
  orm.settings.set 'connection.reconnect', false
  path = "#{process.cwd()}/#{parsed.pathname.substr(1)}"
  process.env.DATABASE_URL = "sqlite://#{path}"

module.exports = process.env
