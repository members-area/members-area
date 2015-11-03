Controller = require 'members-area/app/controller'

module.exports = class PinCodes extends Controller
  @before 'ensureAdmin', only: ['settings']
  @before 'loadRoles', only: ['settings']
  @before 'loadEntries', only: ['settings']

  open: (done) ->
    @rendered = true # We're handling rendering
    secret = @plugin.get('apiSecret')
    error = (code, object) =>
      @res.json code, object
      return done()
    if !secret?.length or @req.cookies.SECRET != secret
      return error 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
    else
      {user_id, location, successful} = @req.body
      whenEntered = @req.body.when

      user_id = parseInt(user_id ? 0, 10) if user_id?
      location = String(location ? "")
      successful = !!(String(successful ? "1") isnt "0")
      whenEntered = new Date(parseInt(whenEntered, 10))

      return error 400, {errorCode: 400, errorMessage: "Invalid user_id"} unless !user_id? or (isFinite(user_id) and user_id > 0)
      return error 400, {errorCode: 400, errorMessage: "No location specified"} unless location?.length
      return error 400, {errorCode: 400, errorMessage: "Invalid date"} unless whenEntered.getFullYear() >= 2014

      entry =
        user_id: user_id
        location: location
        successful: successful
        when: whenEntered

      @req.models.Pinentry.create [entry], (err) =>
        if err
          console.error "ERROR OCCURRED SAVING PINENTRY"
          console.dir err
          return error 500, "Could not create model"
        @res.json {success: true}
        done()

  list: (done)->
    @rendered = true # We're handling rendering
    secret = @plugin.get('apiSecret')
    if !secret?.length or @req.cookies.SECRET != secret
      @res.json 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
      return done()
    else
      memberRoleId    = @plugin.get('memberRoleId') ? 1
      keyholderRoleId = @plugin.get('keyholderRoleId') ? 2
      @req.models.User.find().run (err, users) =>
        codes = {}
        if err
          @res.json 500, {errorCode: 500, errorMessage: err}
          console.log err
          return done(err)

        for u in users when hash = u.meta.hashedPincode
          codes[u.id] =
            username: u.username
            fullname: u.fullname
            user_id: u.id
            hashed_pincode: hash
            keyholder: (keyholderRoleId in u.activeRoleIds)
            member: (memberRoleId in u.activeRoleIds)
        @res.json codes
      return done()

  settings: (done) ->
    @data.memberRoleId ?= @plugin.get('memberRoleId') ? 1
    @data.keyholderRoleId ?= @plugin.get('keyholderRoleId') ? 2
    @data.apiSecret ?= @plugin.get('apiSecret')

    @data.memberRoleId = parseInt(@data.memberRoleId, 10)
    @data.keyholderRoleId = parseInt(@data.keyholderRoleId, 10)

    if @req.method is 'POST'
      @plugin.set {apiSecret: @data.apiSecret, memberRoleId: @data.memberRoleId, keyholderRoleId: @data.keyholderRoleId}
    done()

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)

  loadEntries: (done) ->
    @req.models.Pinentry.find().order('-id').limit(50).run (err, @entries) =>
      return done err if err
      userIds = []
      userIds.push entry.user_id for entry in @entries when entry.user_id > 0 and entry.user_id not in userIds
      if userIds.length
        @req.models.User.find().where("id in (#{userIds.join(", ")})").run (err, users) =>
          return done err if err
          userById = {}
          userById[user.id] = user for user in users
          for entry in @entries
            entry.user = userById[entry.user_id]
          done()
      else
        done()
