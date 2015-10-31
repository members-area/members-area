async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true
        primary: true

      identifier:
        type: 'text'
        required: true

      name:
        type: 'text'
        required: true

      meta:
        type: 'object'
        required: true

      createdAt:
        type: 'date'
        required: true
        time: true

      updatedAt:
        type: 'date'
        required: true
        time: true

    async.series
      createTable: (next) => @createTable 'transaction_account', columns, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'transaction_account', (err) ->
      console.dir err if err
      done err
