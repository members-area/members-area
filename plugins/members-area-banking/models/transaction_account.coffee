module.exports = (db, models) ->
  TransactionAccount = db.define 'transaction_account', {
    id:
      type: 'number'
      serial: true
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

  TransactionAccount.modelName = 'TransactionAccount'
  return TransactionAccount
