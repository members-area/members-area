async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        required: true
        serial: true

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
      table: 'role'
      columns: ['name']
      unique: true

    async.series
      createTable: (next) => @createTable 'role', columns, next
      addNameIndex: (next) => @addIndex 'role_name_idx', nameIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'role', (err) ->
      console.dir err if err
      done err
