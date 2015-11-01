module.exports = (db, models) ->
  Rfidentry = db.define 'rfidentry', {
    id:
      type: 'number'
      serial: true
      primary: true

    uid:
      type: 'text'
      required: true

    rfidtag_id:
      type: 'number'
      required: false

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


  },
    timestamp: true
    hooks: db.applyCommonHooks {}

  Rfidentry.modelName = 'Rfidentry'
  return Rfidentry
