{catchErrors, expect, reqres, stub, protect} = require './test_helper'
protect()
Controller = require '../app/controller'

describe 'Controller', ->
  @timeout 15000
  it 'callback without watchdog', (done) ->
    class TestController extends Controller
      @before 'nocb'
      @before 'cb'

      nocb: ->
        @var1 = true
      cb: (done) ->
        @var2 = true
        done()
      action: ->
        @var3 = true
      render: ->
        expect(@var1).to.be.true
        expect(@var2).to.be.true
        expect(@var3).to.be.true
        done()

    reqres (req, res) ->
      params = {action: 'action'}
      TestController.handle params, req, res, (err) ->
        expect(err).to.not.exist

  it 'callback with watchdog', (done) ->
    class TestController extends Controller
      @before 'nocb'
      @before 'cb'

      nocb: ->
        @var1 = true
      cb: (done) ->
        @var2 = true
        # DELIBERATELY NOT CALLING done()
      action: ->
        @var3 = true
      render: ->
        expect(false).to.be.true # We should never get here

    TestController.callbackTimeout = 100
    reqres (req, res) ->
      params = {action: 'action'}
      TestController.handle params, req, res, (err) ->
        expect(err).to.exist
        done()
