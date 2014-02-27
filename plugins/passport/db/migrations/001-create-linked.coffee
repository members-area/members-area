# - userId: foreign, required
# - type: string ('twitter', 'facebook', 'github', ...)
# - identifier: string, required
# - meta: JSON

async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        required: true
        serial: true

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

      createdAt:
        type: 'date'
        required: true
        time: true

      updatedAt:
        type: 'date'
        required: true
        time: true

    typeIndex =
      table: 'user_linked'
      columns: ['user_id', 'type']
      unique: true

    identifierIndex =
      table: 'user_linked'
      columns: ['type', 'identifier']
      unique: false

    async.series
      createTable: (next) => @createTable 'user_linked', columns, next
      addEmailIndex: (next) => @addIndex 'user_linked_type_idx', typeIndex, next
      addUsernameIndex: (next) => @addIndex 'user_linked_identifier_idx', identifierIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'user_linked', (err) ->
      console.dir err if err
      done err
