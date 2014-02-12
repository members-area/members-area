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
    user = @req.User.build @data
    user.validate().done (err, @errors) =>
      addError 'base', 'Errors occurred during validation' if err
      return done() if @errors
      @req.sequelize.transaction (t) =>
        user.save(transaction: t).done (err) =>
          if err
            console.dir err
            addError 'base', 'Could not create user'
            return t.rollback()
          # Request base role.
          roles = [@req.app.roles.base]
          if user.id is 1
            roles.push [@req.app.roles.owner]
          user.requestRoles roles, {transaction: t}, (err) =>
            if err
              console.error err
              addError 'base', 'Could not apply for registration'
              return t.rollback()
            @template = "success"
            return t.commit()
        t.done done

  # ---------------

  requireNotLoggedIn: ->
    @redirectTo "/" if @req.user?
