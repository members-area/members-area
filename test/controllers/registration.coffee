{catchErrors, expect, reqres, sinon} = require '../test_helper'
RegistrationController = require '../../controllers/registration'

describe 'RegistrationController', ->
  it 'enables registration', (done) ->
    reqres (req, res) ->
      req.method = 'POST'
      params =
        controller: 'registration'
        action: 'register'
      req.body =
        fullname: 'Southampton Makerspace'
        email: 'example@example.com'
        username: 'Testing'
        address: 'Unit K6, Pitt Road, Southampton, SO15 3FQ'
        password: 's3kr17??'
        password2: 's3kr17??'
        terms: 'on'
      sinon.stub RegistrationController.prototype, "render", catchErrors done, (next) ->
        RegistrationController.prototype.render.restore()
        try
          expect(@template).to.eql "success"
        catch e
          return done e
        done()
      next = catchErrors done, ->
        expect(false)
      RegistrationController.handle params, req, res, next
