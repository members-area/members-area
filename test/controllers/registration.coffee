{catchErrors, expect, reqres, sinon} = require '../test_helper'
RegistrationController = require '../../controllers/registration'

registerWith = (data, done, callback) ->
  reqres (req, res) ->
    req.method = 'POST'
    params =
      controller: 'registration'
      action: 'register'
    req.body = data
    sinon.stub RegistrationController.prototype, "render", catchErrors done, (next) ->
      RegistrationController.prototype.render.restore()
      catchErrors(done, callback).call this
    RegistrationController.handle params, req, res, ->
      console.log new Error().stack
      done new Error("Didn't render?")

describe 'RegistrationController', ->
  it 'enables registration', (done) ->
    data =
      fullname: 'Southampton Makerspace'
      email: 'example@example.com'
      username: 'Testing'
      address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
      password:  's3kr17??'
      password2: 's3kr17??'
      terms: 'on'
    registerWith data, done, (err) ->
      return done err if err
      expect(@template).to.eql "success"
      done()

  it 'requires passwords to match', (done) ->
    data =
      fullname: 'Southampton Makerspace'
      email: 'example@example.com'
      username: 'Testing'
      address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
      password:  's3kr17!?'
      password2: 's3kr17?!'
      terms: 'on'
    registerWith data, done, (err) ->
      return done err if err
      expect(@template).to.eql "register"
      expect(@errors).to.be.an 'object'
      expect(@errors.password).to.eql ['Passwords do not match']
      done()
