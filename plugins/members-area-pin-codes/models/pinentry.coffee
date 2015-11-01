module.exports = (db, models) ->
  Pinentry = db.define 'pinentry', {
    id:
      type: 'number'
      serial: true
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

  Pinentry.modelName = 'Pinentry'
  return Pinentry
