async = require 'async'

module.exports =
  up: (done) ->
    rfidtagColumns =
      id:
        type: 'number'
        serial: true
        required: true
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

    rfidtagUserIndex =
      table: 'rfidtag'
      columns: ['user_id']
      unique: false

    rfidtagUidIndex =
      table: 'rfidtag'
      columns: ['uid']
      unique: true

    rfidentryColumns =
      id:
        type: 'number'
        serial: true
        required: true
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

    rfidentryUserIndex =
      table: 'rfidentry'
      columns: ['user_id', 'when']
      unique: false

    rfidentryRfidtagIndex =
      table: 'rfidentry'
      columns: ['rfidtag_id']
      unique: false


    async.series
      createRfidtagTable: (next) =>
        @createTable 'rfidtag', rfidtagColumns, next

      createRfidentryTable: (next) =>
        @createTable 'rfidentry', rfidentryColumns, next

      addRfidtagUidIndex: (next) =>
        @addIndex 'rfidtag_uid_ref_idx', rfidtagUidIndex, next

      addRfidtagUserIndex: (next) =>
        @addIndex 'rfidtag_user_ref_idx', rfidtagUserIndex, next

      addRfidentryUserIndex: (next) =>
        @addIndex 'rfidentry_user_ref_idx', rfidentryUserIndex, next

      addRfidentryRfidtagIndex: (next) =>
        @addIndex 'rfidentry_rfidtag_ref_idx', rfidentryRfidtagIndex, next
    , (err) ->
      console.dir err if err
      done err

  down: (done) ->
    @dropTable 'rfidtag', (err) ->
      console.dir err if err
      return done(err) if err
      @dropTable 'rfidentry', (err) ->
        console.dir err if err
        done err
