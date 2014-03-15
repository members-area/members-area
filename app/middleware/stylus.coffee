nib = require 'nib'
stylus = require 'stylus'
path = require 'path'

publicDir = path.join(__dirname, "..", "..", 'public')
cssDir = path.join(publicDir, 'css')

stylusCompile = (str, path) ->
  return stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())
    .use (style) -> style.include(cssDir)

module.exports = (src = publicDir) -> stylus.middleware
  src: src
  compile: stylusCompile
