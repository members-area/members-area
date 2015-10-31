LoggedInController = require 'members-area/app/controllers/logged-in'
async = require 'async'
_ = require 'underscore'
Reprocessor = require '../reprocessor'

class GoCardlessController extends LoggedInController
  @callbackTimeout: 240000
  @before 'requireAdmin'
  @before 'setActiveNagivationId'
  @before 'saveSettings', only: ['admin']
  @before 'cancelPreauth', only: ['preauths']
  @before 'getUsers', only: ['preauths', 'bills', 'subscriptions']
  @before 'getSubscriptions', only: ['subscriptions', 'bills']
  @before 'getPreauths', only: ['preauths', 'bills']
  @before 'getBills', only: ['bills']
  @before 'reprocess', only: ['bills']
  @before 'updateSubscriptions', only: ['subscriptions']

  admin: ->

  subscriptions: ->

  preauths: ->

  do_preauths: (done) ->
    return @redirectTo "/admin/gocardless/preauths/dr" if @req.method isnt 'POST' or @req.body.confirm isnt 'confirm'
    @plugin.createNewBillsWithModels @req.models, dryRun: false, (@err, @results) =>
      done()

  dr_preauths: (done) ->
    @plugin.createNewBillsWithModels @req.models, dryRun: true, (@err, @results) =>
      @dryRun = true
      @template = 'do_preauths'
      done()

  payouts: (done) ->
    @client().payout.index (err, res, body) =>
      @payoutList = JSON.parse body
      done()

  bills: ->

  cancelPreauth: (done) ->
    return done() unless @req.method is 'POST' and @req.body.cancel
    @client().preAuthorization.cancel {id:@req.body.cancel}, (err, res, body) =>
      try
        body = JSON.parse body if typeof body is 'string'
        throw new Error(body.error.join(" \n")) if body.error
        console.log "Cancelled preauth #{@req.body.cancel}"
      catch e
        err ?= e
      done err

  getUsers: (done) ->
    @req.models.User.all (err, @users) =>
      @usersById = {}
      @usersById[user.id] = user for user in @users
      done(err)

  getBills: (done) ->
    @client().bill.index (err, res, body) =>
      try
        body = JSON.parse body if typeof body is 'string'
        throw new Error(body.error.join(" \n")) if body.error
        @billList = body
        for bill in @billList when bill.source_type is 'subscription'
          for subscription in @subscriptionList when subscription.id is bill.source_id
            bill.subscription = subscription
        for bill in @billList when bill.source_type is 'pre_authorization'
          for preauth in @preauthList when preauth.id is bill.source_id
            bill.preauth = preauth
      catch e
        err ?= e
      done()

  getSubscriptions: (done) ->
    @client().subscription.index (err, res, body) =>
      try
        body = JSON.parse body if typeof body is 'string'
        throw new Error(body.error.join(" \n")) if body.error
        @subscriptionList = body
      catch e
        err ?= e
      done(err)

  updateSubscriptions: (done) ->
    return done() unless @req.method is 'POST' and @req.body.update is 'update'
    @update = true
    subscriptionByUserId = {}
    subscriptionByUserId[parseInt(s.name.substr(1), 10)] = s for s in @subscriptionList when s.status is 'active'
    checkUser = (user, next) ->
      s = subscriptionByUserId[user.id]
      gc = _.clone user.meta.gocardless ? {}
      update = ->
        user.setMeta gocardless: gc
        user.save next
      if s
        s.user = user
        gc.subscription_resource_id = s.id
        update()
      else
        if gc.subscription_resource_id
          delete gc.subscription_resource_id
          update()
        else
          next()
    async.eachSeries @users, checkUser, done

  getPreauths: (done) ->
    @client().preAuthorization.index (err, res, body) =>
      try
        body = JSON.parse body if typeof body is 'string'
        throw new Error(body.error.join(" \n")) if body.error
        @preauthList = body
        @preauthList.filter((p) -> p.name.match /^M[0-9]+$/).forEach (preauth) =>
          preauth.user = @usersById[parseInt(preauth.name.substr(1), 10)]
        preauthById = {}
        preauthById[p.id] = p for p in @preauthList
        relevantUsers = @users.filter((user) -> user.meta.gocardless?.resource_id)
        checkPreauth = (user, next) =>
          preauth = preauthById[user.meta.gocardless.resource_id]
          if !preauth or preauth.status isnt 'active'
            console.error "REMOVING USER #{user.id}'s gocardless resource_id"
            gocardless = user.meta.gocardless
            delete gocardless.resource_id
            delete gocardless.paidInitial
            user.setMeta gocardless: gocardless
            user.save next
          else
            next()
        async.eachSeries relevantUsers, checkPreauth, done
        return
      catch e
        err ?= e
      done(err)

  requireAdmin: (done) ->
    unless @req.user and @req.user.can('admin')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    else
      done()

  saveSettings: (done) ->
    if @req.method is 'POST'
      fields = ['appId', 'appSecret', 'merchantId', 'token']
      data = {}
      data[field] = @req.body[field] for field in fields
      data.sandbox = (@req.body.sandbox is 'on')
      gocardless = require('gocardless')(data)
      gocardless.merchant.getSelf (err, response, body) =>
        try
          throw err if err
          body = JSON.parse(body)
          throw new Error(body.error.join(" \n")) if body.error
          @successMessage = "We checked with GoCardless and you've successfully identified as merchant #{data.merchantId} :)"
          @plugin.set data, done
        catch err
          console.dir err
          @errorMessage = err.message || "An error occurred"
          done()
    else
      @data = @plugin.get()
      done()

  client: ->
    @gocardlessClient ||= require('gocardless')(@plugin.get())

  setActiveNagivationId: ->
    @activeNavigationId = 'members-area-gocardless-admin'

  reprocess: (done) ->
    return done() unless @req.method is 'POST' and @req.body.reprocess
    options =
      models: @req.models
      plugin: @plugin
      # The following are added for efficiency, no point doing this twice
      usersById: @usersById
      users: @users
      preauthList: @preauthList
      subscriptionList: @subscriptionList
      billList: @billList
      gocardlessClient: @gocardlessClient
    reprocessor = new Reprocessor options
    reprocessor.reprocess done

module.exports = GoCardlessController
