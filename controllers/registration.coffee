Controller = require '../controller'

module.exports = class RegistrationController extends Controller
  @before 'requireNotLoggedIn'

  constructor: ->
    super
    @data[k] = null for k, v of @data when v is ""

  register: (done) ->
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

    delete @data.url
    delete @data.terms
    delete @data.password2
    @req.db.transaction (err, t) =>
      return done err if err
      @req.models.User.create @data, (err, user) =>
        if err
          if Array.isArray(err)
            @errors = @req.models.User.groupErrors err
          else
            addError 'base', 'Errors occurred during validation'
          return t.rollback done
        # Request base role.
        baseRoleId = 1
        ownerRoleId = 2
        roles = [baseRoleId]
        if user.id is 1
          roles.push ownerRoleId
        user.requestRoles roles, (err) =>
          if err
            console.error err
            console.log err.stack
            addError 'base', 'Could not apply for registration'
            return t.rollback done
          t.commit (err) =>
            return done err if err
            @template = "success"
            done()


  # ---------------

  requireNotLoggedIn: ->
    @redirectTo "/" if @req.user?
