LoggedInController = require 'members-area/app/controllers/logged-in'
async = require 'async'

class PaymentsController extends LoggedInController
  @before 'setActiveNagivationId'
  @before 'requireAdmin'
  @before 'saveSettings', only: ['index']
  @before 'getPayment', only: ['view']
  @before 'updatePayment', only: ['view']
  @before 'cancelPayment', only: ['view']

  index: (done) ->
    limit = 25
    page = parseInt(@req.query.page, 10) || 0
    page = 0 if page < 0
    @page = page

    @req.models.Payment.find({}, {autoFetch: true})
    .order("-id")
    .offset(page * limit)
    .limit(limit)
    .run (err, @payments) =>
      @hasNext = @payments.length is limit
      @hasPrev = @page > 0
      done(err)

  view: ->

  getPayment: (done) ->
    @req.models.Payment.get @req.params.id, autoFetch: true, (err, @payment) =>
      @cancelable = @plugin.customPaymentMethods[@payment.type]?
      done(err)

  _updatePayment: (payment, diff, done) ->
    payment.save (err) =>
      return done err if err
      paidUntil = new Date +payment.user.paidUntil
      paidUntil.setMonth(paidUntil.getMonth() + diff)
      payment.user.paidUntil = paidUntil
      payment.user.save (err) =>
        return done err if err
        midnight = new Date +payment.period_from
        midnight.setHours(0)
        midnight.setMinutes(0)
        midnight.setSeconds(0)
        @req.models.Payment.find()
          .where("id <> ? AND user_id = ? AND period_from >= ? AND include = ?", [payment.id, payment.user_id, midnight, true])
          .all (err, paymentsToRewrite) =>
            return done err if err
            rewrite = (p, done) ->
              from = new Date +p.period_from
              from.setMonth(from.getMonth() + diff)
              p.period_from = from
              p.save done
            async.eachSeries paymentsToRewrite, rewrite, ->
              console.log "Changed #{payment.user.fullname}'s paid until by #{diff} month(s) at admin's request"
              done null, payment

  cancelPayment: (done) ->
    return done() unless @req.method is 'POST'
    if @req.body.cancel is 'cancel'
      payment = @payment
      return done() unless payment.include
      payment.include = false
      @_updatePayment(payment, -payment.period_count, done)
    else
      return done()

  updatePayment: (done) ->
    return done() unless @req.method is 'POST' and @req.body.period_count
    periodCount = parseInt(@req.body.period_count, 10)
    diff = periodCount - @payment.period_count
    return done() if diff is 0
    payment = @payment
    payment.period_count = periodCount
    @_updatePayment(payment, diff, done)

  requireAdmin: (done) ->
    unless @req.user and @req.user.can('admin')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    else
      done()

  setActiveNagivationId: ->
    @activeNavigationId = 'members-area-payments'

  saveSettings: (done) ->
    if @req.method is 'POST'
      @plugin.set @data, done
    else
      @data = @plugin.get()
      done()

module.exports = PaymentsController
