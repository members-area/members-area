async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true
        primary: true

      user_id:
        type: 'number'
        required: false

      location:
        type: 'text'
        required: true

      successful:
        type: 'boolean'
        required: true

      when:
        type: 'date'
        required: true
        time: true

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

    pinentryUserIndex =
      table: 'pinentry'
      columns: ['user_id', 'when']
      unique: false

    async.series
      createTable: (next) => @createTable 'pinentry', columns, next
      addPaymentUserIndex: (next) => @addIndex 'pinentry_ref_idx', pinentryUserIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'pinentry', (err) ->
      console.dir err if err
      done err
