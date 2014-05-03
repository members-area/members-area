async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true
        primary: true

      role_id:
        type: 'number'
        required: true

      user_id:
        type: 'number'
        required: true

      approved:
        type: 'date'
        required: false

      rejected:
        type: 'date'
        required: false

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

    roleUserIndex =
      table: 'role_user'
      columns: ['user_id', 'role_id']
      unique: false

    async.series
      createTable: (next) => @createTable 'role_user', columns, next
      addRoleUserIndex: (next) => @addIndex 'role_user_ref_idx', roleUserIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'role_user', (err) ->
      console.dir err if err
      done err
