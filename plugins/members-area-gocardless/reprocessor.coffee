async = require 'async'
_ = require 'underscore'

reconciliationInProgress = false

class Reprocessor
  constructor: (options) ->
    for k,v of options
      this[k] ?= v

  client: ->
    @gocardlessClient ||= require('gocardless')(@plugin.get())

  getUsers: (done) ->
    return done() if @users and @usersById
    @models.User.all (err, @users) =>
      @usersById = {}
      @usersById[user.id] = user for user in @users
      done(err)

  getPreauths: (done) ->
    return done() if @preauthList
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

  getSubscriptions: (done) ->
    return done() if @subscriptionList
    @client().subscription.index (err, res, body) =>
      try
        body = JSON.parse body if typeof body is 'string'
        throw new Error(body.error.join(" \n")) if body.error
        @subscriptionList = body
      catch e
        err ?= e
      done(err)

  getBills: (done) ->
    return done() if @billList
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

  # This method prevents multiple requests from doing multiple reconciliations at the same time.
  reprocess: (done, attempts = 0) ->
    doIt = =>
      if reconciliationInProgress
        if attempts < 10
          attempts++
          console.error "Tried to do two reconciliations at once? Trying again in 500ms (attempt: #{attempt})"
          setTimeout doIt, 500
        else
          done new Error "Conflict"
      else
        reconciliationInProgress = true
        @_reprocess ->
          reconciliationInProgress = false
          done.apply this, arguments
    doIt()

  _reprocess: (done) ->
    async.series [
      @getUsers.bind(this)
      @getSubscriptions.bind(this)
      @getPreauths.bind(this)
      @getBills.bind(this)
    ], =>
      @_reprocess2 done

  _reprocess2: (done) ->
    paymentsByUser = {}
    regex = /^M(0[0-9]+)$/
    for bill in @billList when (matches = (bill.subscription ? bill.preauth ? bill).name?.match regex)
      userId = parseInt matches[1], 10
      paymentsByUser[userId] ?= []
      paymentsByUser[userId].push bill

    async.map _.pairs(paymentsByUser), @_processUserBills.bind(this), (err, groupedNewRecords) ->
      done err

  _processUserBills: ([userId, bills], done) ->
    bills.sort (a, b) -> Date.parse(a.created_at) - Date.parse(b.created_at)
    return done() unless bills.length
    @models.User.get userId, (err, user) =>
      console.error err if err
      if !user
        console.error "Could not find user '#{userId}'"
      return done null, null if err or !user
      @models.Payment.find()
      .where(type:'GC', user_id: userId)
      .run (err, payments) =>
        console.error err if err
        if !payments
          console.error "Could not load payments for '#{userId}'"
        return done null, null if err or !payments
        nextPaymentDate = user.getPaidUntil new Date Date.parse bills[0].created_at

        updatedRecords = []
        newRecords = []

        paymentsByGocardlessBillId = {}
        paymentsByGocardlessBillId[p.meta.gocardlessBillId] = p for p in payments when p.meta.gocardlessBillId?

        for bill in bills
          existingPayment = paymentsByGocardlessBillId[bill.id]

          status = @mapStatus(bill.status)
          amount = Math.round((parseFloat(bill.amount) - parseFloat(bill.gocardless_fees)) * 100)
          periodCount = 1

          if existingPayment
            if existingPayment.status isnt status or existingPayment.amount isnt amount or existingPayment.user_id isnt userId
              if existingPayment.status isnt status
                existingPayment.status = status
                if bill.status in ['failed', 'cancelled']
                  # Deactiveate bill
                  existingPayment.include = false
                  # Decrease paidUntil
                  nextPaymentDate = new Date(+nextPaymentDate)
                  nextPaymentDate.setMonth(nextPaymentDate.getMonth()-existingPayment.period_count)
              existingPayment.amount = amount
              existingPayment.user_id = userId
              updatedRecords.push existingPayment
          else
            if user.meta.gocardless
              gocardless = user.meta.gocardless
              if gocardless.paidInitial? and !gocardless.paidInitial and gocardless.initial > 0 and gocardless.monthly > 0
                periodCount += Math.round(gocardless.initial / gocardless.monthly)
              gocardless.paidInitial = true
              user.setMeta gocardless: gocardless
            payment =
              user_id: userId
              transaction_id: null
              type: 'GC'
              amount: amount
              status: status
              include: bill.status not in ['failed', 'cancelled']
              when: new Date Date.parse bill.created_at
              period_from: nextPaymentDate
              period_count: periodCount
              meta:
                gocardlessBillId: bill.id
            newRecords.push payment
            if payment.include
              nextPaymentDate = new Date(+nextPaymentDate)
              nextPaymentDate.setMonth(nextPaymentDate.getMonth()+periodCount)
        user.paidUntil = nextPaymentDate
        async.series
          updatePayments: (done) => async.eachSeries updatedRecords, ((r, done) -> r.save done), done
          createPayments: (done) => @models.Payment.create newRecords, done
          savePaidUntil: (done) => user.save done
        , (err) =>
          console.dir err if err
          done err, newRecords

  mapStatus: (status) ->
    # Takes a gocardless status and translates into a members area status
    map =
      'paid': 'paid'
      'failed': 'failed'
      'cancelled': 'cancelled'
      'pending': 'pending'
      'withdrawn': 'paid'
    return map[status] ? status

module.exports = Reprocessor
