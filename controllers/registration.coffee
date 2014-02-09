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
      addError 'base', 'you appear to be a spammer'
    unless @data.terms is 'on'
      addError 'terms', 'you must accept the terms'
    unless @data.password is @data.password2
      addError 'password', 'passwords do not match'

    return done() if @errors

    delete @data.url
    delete @data.terms
    delete @data.password2
    user = @req.User.build @data
    user.validate().done (err, @errors) =>
      addError 'base', 'errors occurred during validation' if err
      return done() if @errors
      user.save().done (err) =>
        addError 'base', 'could not create user' if err
        return done() if @errors
        return done()

  # ---------------

  requireNotLoggedIn: ->
    @redirectTo "/" if @req.user?
