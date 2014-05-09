module.exports = (db, models) ->
  Setting = db.define 'setting', {
    id:
      type: 'number'
      serial: true
      primary: true

    name:
      type: 'text'
      required: true

    meta:
      type: 'object'
      required: true
      defaultValue: {}
  },
    timestamp: true
    hooks: db.applyCommonHooks {}

  Setting.seedData = [
    {
      name: "email"
      meta:
        settings: {}
    }
  ]

  Setting.modelName = 'Setting'
  return Setting
