Controller = require 'members-area/app/controller'
_ = require 'underscore'
async = require 'async'

module.exports = class Rfidtags extends Controller
  @before 'ensureAdmin', only: ['settings']
  @before 'loadRoles', only: ['settings']
  @before 'loadEntries', only: ['settings']
  @before 'verifySecret', only: ['list']
  @before 'receive', only: ['list']

  verifySecret: (done) ->
    secret = @plugin.get('apiSecret')
    if !secret?.length or @req.cookies.SECRET != secret
      @rendered = true # We're handling rendering
      @res.json 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
    return done()

  receive: (done) ->
    return done() unless @req.method in ['POST', 'PUT']
    error = (status, obj) =>
      @rendered = true # We're handling rendering
      @res.json status, obj
      return done()

    if !@req.body?.tags
      return error 400, {errorCode: 400, errorMessage: "Invalid POST data"}

    {tags} = @req.body
    tagUids = Object.keys(tags)

    req = @req
    receiveTag = (tagUid, done) =>
      req.models.Rfidtag.find()
        .where('uid = ?', [tagUid])
        .first (err, tag) =>
          error = (status, obj) =>
            @rendered = true # We're handling rendering
            @res.json status, obj
            return done(new Error("Failed on tag '#{tagUid}'"))
          return done err if err
          if !tag
            # Create it
            remoteTag = tags[tagUid]
            if remoteTag.assigned_user
              return error 403, {errorCode: 403, errorMessage: "You can't assign a new token!"}
            secrets = {}
            for k, v of remoteTag when k.match /^sector_/
              secrets[k] = v
            tag = new req.models.Rfidtag
              uid: tagUid
              count: remoteTag.count
              secrets: secrets
              meta: {}
            tag.save (err) ->
              if err
                console.dir err
                return error 400, {errorCode: 400, errorMessage: "Couldn't create tag"}
              return done()
          else
            return done()
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

            @req.models.Rfidentry.create [entry], (err) =>
              if err
                console.error "ERROR OCCURRED SAVING RFIDENTRY"
                console.dir err
                return error 500, "Could not create model"
              @res.json {success: true}
              done()

    async.eachSeries tagUids, receiveTag, done


  list: (done) ->
    @rendered = true # We're handling rendering
    secret = @plugin.get('apiSecret')
    if !secret?.length or @req.cookies.SECRET != secret
      @res.json 401, {errorCode: 401, errorMessage: "Invalid or no auth"}
      return done()
    else
      @req.models.Rfidtag.find().run (err, tags) =>
        @req.models.User.find().run (err2, users) =>
          err ||= err2
          if err
            @res.json 500, {errorCode: 500, errorMessage: err}
            console.error err.stack ? err
            return done(err)

          result =
            tags: {}
            users: {}

          padUserId = (id) ->
            return null unless id?
            targetLength = 6
            id = String(id)
            if id.length < targetLength
              id = new Array(targetLength - id.length + 1).join("0") + id
            return id

          for tag in tags
            result.tags[tag.uid] = _.extend {}, tag.secrets,
              assigned_user: padUserId(tag.user_id)
              count: tag.count

          for u in users
            users[padUserId(u.id)] =
              name: u.fullname
              roles: u.activeRoleIds
          @res.json result
          return done()

  settings: (done) ->
    @data.apiSecret ?= @plugin.get('apiSecret')

    if @req.method is 'POST'
      @plugin.set {apiSecret: @data.apiSecret}
    done()

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)

  loadEntries: (done) ->
    @req.models.Rfidentry.find().order('-id').limit(50).run (err, @entries) =>
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

  ensureAdmin: (done) ->
    return @redirectTo "/login?next=#{encodeURIComponent @req.path}" unless @req.user?
    return done new @req.HTTPError 403, "Permission denied" unless @req.user.can('admin')
    done()
