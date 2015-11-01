module.exports = (db, models) ->
  Rfidtag = db.define 'rfidtag', {
    id:
      type: 'number'
      serial: true
      primary: true

    uid:
      type: 'text'
      required: true

    user_id:
      type: 'number'
      required: false

    count:
      type: 'number'
      required: true

    secrets:
      type: 'object'
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

  },
    timestamp: true
    hooks: db.applyCommonHooks {}

  Rfidtag.modelName = 'Rfidtag'
  return Rfidtag
