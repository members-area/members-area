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
        required: true

      transaction_id:
        type: 'number'
        required: false

      type:
        type: 'text'
        required: true

      amount:
        type: 'number'
        required: true

      status:
        type: 'text'
        required: true

      include:
        type: 'boolean'
        required: true

      when:
        type: 'date'
        required: true

      period_from:
        type: 'date'
        required: true

      period_count:
        type: 'number'
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

    paymentUserIndex =
      table: 'payment'
      columns: ['user_id', 'when']
      unique: false

    async.series
      createTable: (next) => @createTable 'payment', columns, next
      addPaymentUserIndex: (next) => @addIndex 'payment_ref_idx', paymentUserIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'payment', (err) ->
      console.dir err if err
      done err
