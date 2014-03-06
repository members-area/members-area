#!/usr/bin/env node
crypto = require 'crypto'
fs = require 'fs'
child_process = require 'child_process'

arg = process.argv[2]

usage = ->
  console.log """
    Usage:

      init    - set up a members are in the current folder
      migrate - migrate the database
      seed    - seed the database
      setup   - migrate then seed
    """

cwd = process.cwd()

methods =
  migrate: ->
    console.log "MIGRATE"

  init: ->
    console.log "Initialising a members area in #{cwd}"
    files = fs.readdirSync cwd
    unless files.indexOf("package.json") >= 0
      console.error "Please run `npm init` first."
      process.exit 1
    for file in files
      unless file.match /^(\..*|package.json|node_modules)$/
        console.error "Folder is not empty: '#{file}' forbidden"
        process.exit 1
    pkg = require "#{cwd}/package.json"
    pkg.scripts ?= {}
    pkg.scripts.start ?= "coffee index.coffee"
    pkg.plugins ?= {}
    pkg.plugins['members-area-passport'] = '*'
    fs.writeFileSync "package.json", JSON.stringify pkg, null, 2
    child_process.exec "npm install --save members-area", (err) ->
      throw err if err
    fs.writeFileSync ".gitignore", """
      *.sqlite
      config/
      log/
      node_modules/
      sessions/
      """
    fs.writeFileSync "index.coffee", """
      MembersArea = require 'members-area'
      MembersArea.start()
      """
    fs.mkdirSync "config"
    fs.mkdirSync "log"
    fs.mkdirSync "sessions"
    fs.writeFileSync "config/db.json", JSON.stringify
      development: "sqlite:///members.sqlite"
      test: "sqlite:///members-test.sqlite"
    crypto.randomBytes 18, (err, bytes) ->
      fs.writeFileSync "config/settings.json", JSON.stringify
        secret: bytes?.toString('base64') ? "PutSecureSecretHere"
        serverAddress: "http://localhost:1337"

fn = methods[arg]
if fn?
  fn()
else
  usage()
