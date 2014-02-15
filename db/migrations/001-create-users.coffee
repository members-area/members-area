async = require 'async'

module.exports =
  up: (done) ->
    columns =
      id:
        type: 'number'
        serial: true
        required: true
        primary: true

      email:
        type: 'text'
        required: true
        unique: true

      username:
        type: 'text'
        required: true

      password:
        type: 'text'
        required: true

      paidUntil:
        type: 'date'
        required: false
        time: false

      fullname:
        type: 'text'
        required: false

      address:
        type: 'text'
        required: false

      verified:
        type: 'date'
        required: false
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

    emailIndex =
      table: 'users'
      columns: ['email']
      unique: true

    usernameIndex =
      table: 'users'
      columns: ['username']
      unique: true

    async.series
      createTable: (next) => @createTable 'user', columns, next
      addEmailIndex: (next) => @addIndex 'user_email_idx', emailIndex, next
      addUsernameIndex: (next) => @addIndex 'user_username_idx', usernameIndex, next
    , done

  down: (done) ->
    @dropTable 'user', done
