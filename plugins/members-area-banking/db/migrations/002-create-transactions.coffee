async = require 'members-area/node_modules/async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true
        primary: true

      transaction_account_id:
        type: 'number'
        required: true

      fitid:
        type: 'text'
        required: true

      when:
        type: 'date'
        required: true

      type:
        type: 'text'
        required: true

      description:
        type: 'text'
        required: true

      amount:
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

    transactionAccountIndex =
      table: 'transaction'
      columns: ['transaction_account_id', 'when']
      unique: false

    fitidIndex =
      table: 'transaction'
      columns: ['transaction_account_id', 'fitid']
      unique: true

    async.series
      createTable: (next) => @createTable 'transaction', columns, next
      addTransactionAccountIndex: (next) => @addIndex 'transaction_account_ref_idx', transactionAccountIndex, next
      addFitidIndex: (next) => @addIndex 'fitid_unique_idx', fitidIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'transaction', (err) ->
      console.dir err if err
      done err
