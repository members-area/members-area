nib = require 'nib'
stylus = require 'stylus'
path = require 'path'

publicDir = path.join(__dirname, "..", "..", 'public')
cssDir = path.join(publicDir, 'css')

stylusCompile = (str, path) ->
  sto = stylus(str)
    .set('filename', path)
    .set('compress', true)
    .use(nib())
    .include(cssDir)
  for path in module.exports.imports
    sto.import(path)
  return sto

module.exports = (src = publicDir) -> stylus.middleware
  src: src
  compile: stylusCompile

module.exports.imports = []
