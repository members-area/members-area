module.exports = (db, models) ->
  models.UserLinked = models.User.extendsTo 'linked', {
    user_id:
      type: 'number'
      serial: true
      primary: true

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
  return UserLinked
