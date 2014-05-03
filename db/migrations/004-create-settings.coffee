async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        required: true
        serial: true
        primary: true

      name:
        type: 'text'
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

    nameIndex =
      table: 'setting'
      columns: ['name']
      unique: true

    async.series
      createTable: (next) => @createTable 'setting', columns, next
      addNameIndex: (next) => @addIndex 'setting_name_idx', nameIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'setting', (err) ->
      console.dir err if err
      done err
