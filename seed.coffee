async = require 'async'
models = (model for name, model of require('./models') when name.match /^[A-Z]/)

seed = (model, callback) ->
  model.seed callback

done = (err) ->
  if err
    console.error "Error:", err
    process.exit 1
  else
    console.log "All done"

async.mapSeries models, seed, done
