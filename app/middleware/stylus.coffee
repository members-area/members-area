nib = require 'nib'
stylus = require 'stylus'
path = require 'path'

cssDir = path.join(__dirname, "..", "..", 'public')

stylusCompile = (str, path) ->
  return stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())
    .use (style) -> style.include(cssDir)

module.exports = (src = cssDir) -> stylus.middleware
  src: src
  compile: stylusCompile
