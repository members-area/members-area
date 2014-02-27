module.exports = (db, models) ->
  UserLinked = db.define 'user_linked', {
    id:
      type: 'number'
      serial: true
      primary: true

    user_id:
      type: 'number'
      required: true

    type:
      type: 'text'
      required: true
      unique: true

    identifier:
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

  UserLinked.modelName = 'UserLinked'
  UserLinked.hasOne 'user', models.User, reverse: 'userLinkeds', autoFetch: true
  return UserLinked
