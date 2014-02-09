Controller = require '../controller'

module.exports = class RegistrationController extends Controller
  @before 'requireNotLoggedIn'

  register: (done) ->
    return done() unless @req.method is 'POST'
    # Process data
    @errors = null
    addError = (field, message) =>
      @errors ?= {}
      @errors[field] ?= []
      @errors[field].push message

    unless @req.body.url?.length is 0
      addError 'base', 'you appear to be a spammer'
    unless @req.body.terms is 'on'
      addError 'terms', 'you must accept the terms'
    unless @req.body.password is @req.body.password2
      addError 'password', 'passwords do not match'

    return done() if @errors

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
