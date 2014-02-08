fs = require 'fs'
winston = require 'winston'
express = require 'express'

try
  fs.mkdirSync 'log'

winston.remove winston.transports.Console
winston.add winston.transports.Console, timestamp: true, colorize: true if process.env.NODE_ENV is 'development'
winston.add winston.transports.File, {filename: "log/winston-#{process.env.NODE_ENV}.log", maxsize: 50000000, maxFiles: 8, level: 'warn'}
winston.handleExceptions new winston.transports.File {filename: "log/crash-#{process.env.NODE_ENV}.log"}

module.exports = (app) ->
  app.logger = winston

  winstonMiddleware = (req, res, next) ->
    req.logger = winston
    details =
    wrap = (fn) ->
      return (args...) ->
        details = {method: req.method, path: req.path, ip: req.ip}
        fn args, details
    req.info = wrap winston.info
    req.log = req.info
    req.warn = wrap winston.warn
    req.error = wrap winston.error
    return next()

  logStream = fs.createWriteStream "log/access-#{process.env.NODE_ENV}.log", {flags: 'a', mode: 0o600}

  express.logger.token 'user', (req, res) ->
    return "-"
  express.logger.token 'ips', (req, res) ->
    ips = req.ips.slice()
    if ips.indexOf(req.ip) is -1
      ips.unshift(req.ip)
    return ips.join(",")

  loggerMiddleware = express.logger
    stream: logStream
    format: ':ips - - [:date] ":method :url HTTP/:http-version" :status :res[content-length] ":referrer" ":user-agent" - :response-time ms (u::user)'
    buffer: true

  return (req, res, next) ->
    winstonMiddleware req, res, (err) ->
      return next.apply null, arguments if err
      loggerMiddleware req, res, next
