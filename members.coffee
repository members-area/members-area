async = require 'async'
crypto = require 'crypto'
fs = require 'fs'
{exec} = child_process = require 'child_process'

# For use in combination with exec
output = (done) ->
  (err, stdout, stderr) ->
    console.log stdout
    console.error stderr
    done(err)

arg = process.argv[2]

usage = ->
  console.log """
    Usage:

      quickstart - init && migrate && seed
      init       - set up a members are in the current folder
      setup      - migrate && seed
      migrate    - migrate the database
      seed       - seed the database
    """

cwd = process.cwd()

methods = new class
  migrate: (done = ->) =>
    console.log "Migrating"
    exec "#{__dirname}/scripts/db/migrate", {cwd:process.cwd()}, output done

  seed: (done = ->) =>
    console.log "Seeding"
    exec "#{__dirname}/scripts/db/seed", {cwd:process.cwd()}, output done

  quickstart: (done = ->) =>
    async.series [
      @init
      @migrate
      @seed
    ], done

  setup: (done = ->) =>
    async.series [
      @migrate
      @seed
    ], done

  init: (done = ->) =>
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
    fs.writeFileSync ".gitignore", """
      *.sqlite
      config/
      log/
      node_modules/
      sessions/
      """
    fs.writeFileSync "index.coffee", """
      MembersArea = require 'members-area'

      # Make sure we're in the right folder.
      process.chdir __dirname

      MembersArea.start()
      """
    fs.mkdirSync "config"
    fs.mkdirSync "log"
    fs.mkdirSync "public"
    fs.mkdirSync "sessions"
    fs.writeFileSync "config/db.json", JSON.stringify
      development: "sqlite:///members.sqlite"
      test: "sqlite:///members-test.sqlite"
    async.series
      npmInstall: (next) ->
        exec "npm install --save members-area", output (err) ->
          console.error err if err
          console.error "An error occurred installing the members-area module. Try `npm install --save members-area` later."
          # Ignore error
          next()
      setSettings: (next) ->
        crypto.randomBytes 18, (err, bytes) ->
          fs.writeFileSync "config/development.json", JSON.stringify
            secret: bytes?.toString('base64') ? "PutSecureSecretHere"
            serverAddress: "http://localhost:1337"
          next()
    , done

fn = methods[arg]
if fn?
  fn()
else
  usage()
