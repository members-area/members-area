nib = require 'nib'
stylus = require 'stylus'
path = require 'path'

stylusCompile = (str, path) ->
  return stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())

module.exports = -> stylus.middleware
  src: path.join(__dirname, "..", "..", 'public')
  compile: stylusCompile
