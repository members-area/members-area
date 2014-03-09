Parser = require 'jade/lib/parser'
p = require 'path'

viewDir = p.join(__dirname, "..", "views")

oldResolvePath = Parser::resolvePath
Parser::resolvePath = (path, purpose) ->
  if path.charAt(0) is '!'
    path = p.join viewDir, path.substr(1)
    if path.indexOf(".") is -1
      path += ".jade"
    return path
  else
    return oldResolvePath.apply this, arguments
