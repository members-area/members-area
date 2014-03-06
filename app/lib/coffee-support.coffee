coffee = require 'coffee-script'
fs = require 'fs'

cachedSourceMaps = {}

generateSourceMap = (path) ->
  return unless path.match /\.(lit)?coffee$/
  try
    code = fs.readFileSync(path, 'utf8')
    options =
      filename: path
      sourceMap: true
      header: false
    {js, v3SourceMap} = coffee.compile code, options
    v3SourceMap = JSON.parse v3SourceMap
    v3SourceMap.file = path
    v3SourceMap.sourceRoot = ""
    v3SourceMap.sources = [path]
    v3SourceMap = JSON.stringify v3SourceMap
    cachedSourceMaps[path] = {map: v3SourceMap}
  catch e
    cachedSourceMaps[path] = null # Prevent recursion
    console.error "Error occurred generating sourcemap"
    console.error e?.stack
  return cachedSourceMaps[path]

retrieveSourceMap = (path) ->
  if typeof cachedSourceMaps[path] isnt 'undefined'
    return cachedSourceMaps[path]
  else
    return generateSourceMap(path)

if module.filename.match /\.(lit)?coffee$/
  # DIY source map support
  require('source-map-support').install
    retrieveSourceMap: retrieveSourceMap
else
  # Assume source maps have already been compiled
  require('source-map-support').install()
