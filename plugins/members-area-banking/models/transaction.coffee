module.exports = (db, models) ->
  Transaction = db.define 'transaction', {
    id:
      type: 'number'
      serial: true
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
      defaultValue: {}

    createdAt:
      type: 'date'
      required: true
      time: true

    updatedAt:
      type: 'date'
      required: true
      time: true

  },
    timestamp: true
    hooks: db.applyCommonHooks {}

  Transaction.modelName = 'Transaction'
  return Transaction
