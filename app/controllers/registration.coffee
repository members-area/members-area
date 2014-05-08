Controller = require '../controller'
encode = require('entities').encodeXML

module.exports = class RegistrationController extends Controller
  @before 'requireNotLoggedIn'

  constructor: ->
    super
    @data[k] = null for k, v of @data when v is ""

  register: (done) ->
    @title = @app.siteSetting.meta.settings.registrationTitle
    @leadText = @app.siteSetting.meta.settings.registrationLead
    text = @app.siteSetting.meta.settings.registrationText
    if text
      text = encode(text)
      text = text.replace(/\n/g, "<br>")
    @registrationText = text
    return done() unless @req.method is 'POST'
    # Process data
    @errors = null
    addError = (field, message) =>
      @errors ?= {}
      @errors[field] ?= []
      @errors[field].push message

    if @data.url?.length
      addError 'base', 'You appear to be a spammer'
    unless @data.terms is 'on'
      addError 'terms', 'You must accept the terms'
    unless @data.password is @data.password2
      addError 'password', 'Passwords do not match'

    return done() if @errors

    @data = @makeSafe @data
    password = @data.password
    user = new @req.models.User @data
    user.password = password
    @req.db.transaction (err, t) =>
      return done err if err
      user.save (err, user) =>
        if err
          if Array.isArray(err) or err.property?
            @errors = @req.models.User.groupErrors err
          else
            console.error err
            addError 'base', 'Errors occurred during validation'
          return t.rollback done
        # Request base role.
        baseRoleId = 1
        ownerRoleId = 2
        roles = [baseRoleId]
        force = false
        if user.id is 1
          roles.push ownerRoleId
          force = true
        user.requestRoles roles, {force: force}, (err) =>
          if err
            console.error err
            console.log err.stack
            addError 'base', 'Could not apply for registration'
            return t.rollback done
          t.commit (err) =>
            return done err if err
            if user.id is 1
              # Refetch so all the triggers are called
              @req.models.User.get 1, (err, user) =>
                @req.login user, (err) =>
                  @user = user
                  @template = "success"
                  done()
            else
              @template = "success"
              done()

  verify: (done) ->
    {id, code} = @req.query
    return done() unless id and code
    @req.models.User.get id, (err, user) =>
      @valid = true if user?.verified
      return done() if !user? or user.verified
      user.verify code, (err) =>
        @valid = true unless err
        return done()

  # ---------------

  requireNotLoggedIn: ->
    @redirectTo "/" if @req.user?

  makeSafe: (data) ->
    newData = {}
    newData[k] = String(v) for k, v of data when k in ['email', 'username', 'password', 'fullname', 'address'] and v?
    return newData
