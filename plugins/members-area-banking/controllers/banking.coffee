Controller = require 'members-area/app/controller'
_ = require 'underscore'
async = require 'async'
fs = require 'fs'
ofx = require 'ofx'
entities = new (require('html-entities').AllHtmlEntities)

reconciliationInProgress = false

class BankingController extends Controller
  @before 'setActiveNagivationId'
  @before 'requireAdmin'
  @before 'processOFX', only: ['index']
  @before 'reprocess', only: ['index']

  index: (done) ->
    @req.models.TransactionAccount.find()
    .order("id")
    .all (err, @transactionAccounts) =>
      done(err)

  view: (done) ->
    @req.models.TransactionAccount.get @req.params.id, (err, @transactionAccount) =>
      return done err if err
      @transactionAccount.getTransactions (err, @transactions) =>
        @transactions.sort (a, b) ->
          s = +b.when - +a.when
          return s unless s is 0
          s = b.description.localeCompare(a.description)
          return s unless s is 0
          return +b.amount - a.amount
        done(err)

  requireAdmin: (done) ->
    unless @req.user and @req.user.can('admin')
      err = new Error "Permission denied"
      err.status = 403
      return done err
    else
      done()

  # This method prevents multiple requests from doing multiple reconciliations at the same time.
  reprocess: (done) ->
    return done() unless @req.method is 'POST' and @req.body.reprocess
    doIt = =>
      if reconciliationInProgress
        setTimeout doIt, 500
      else
        reconciliationInProgress = true
        console.log "[#{new Date().toISOString()}] STARTING REPROCESSING BANKING DATA"
        @_reprocess ->
          console.log "[#{new Date().toISOString()}] REPROCESSING BANKING DATA FINISHED"
          reconciliationInProgress = false
          done.apply this, arguments
    doIt()

  _reprocess: (done) ->
    @req.models.Transaction.find().run (err, transactions) =>
      return done err if err
      regex = /^(.*) M(0[0-9]+) ([A-Z]{3})$/
      paymentsByUser = {}
      for tx in transactions when !tx.meta.isPayment and (matches = tx.description?.match(regex))
        tx.accountHolder = matches[1]
        tx.userId = parseInt matches[2], 10
        tx.type = matches[3]
        tx.ymd = tx.when.toISOString().substr(0,10)
        paymentsByUser[tx.userId] ?= []
        paymentsByUser[tx.userId].push tx

      async.map _.pairs(paymentsByUser), @_processUserTransactions.bind(this), (err, groupedNewRecords) ->
        done err

  _processUserTransactions: ([userId, transactions], done) ->
    #{userId, type, ymd, amount} = tx
    transactions.sort (a, b) -> a.when - b.when
    return done() unless transactions.length
    @req.models.User.get userId, (err, user) =>
      if !user
        console.error "Could not find user '#{userId}'"
      return done null, null if err or !user
      nextPaymentDate = user.getPaidUntil transactions[0].when

      newRecords = []

      for tx in transactions
        payment =
          user_id: userId
          transaction_id: tx.id
          type: tx.type
          amount: tx.amount
          status: 'paid'
          include: true
          when: tx.when
          period_from: nextPaymentDate
          period_count: 1
        newRecords.push payment
        nextPaymentDate = new Date(+nextPaymentDate)
        nextPaymentDate.setMonth(nextPaymentDate.getMonth()+1)
      user.paidUntil = nextPaymentDate
      async.series
        createPayments: (done) => @req.models.Payment.create newRecords, done
        setTransactionsAsPayments: (done) =>
          setIsPayment = (tx, done) ->
            tx.setMeta isPayment: true
            tx.save done
          async.eachSeries transactions, setIsPayment, done
        savePaidUntil: (done) => user.save done
      , (err) =>
        done err, newRecords

  processOFX: (done) ->
    return done() unless @req.method is 'POST' and @req.files?.ofxfile?
    path = @req.files.ofxfile.path
    next = (err, result) ->
      fs.unlink path
      if err
        done(err)
      else
        @ofxResults = result
        done()
    @dryRun = !@req.body.commit
    if !!@req.body.dryRun
      @dryRun = true # Just in case they send both

    @parseOFX path, (err, results) =>
      async.map results.accounts, @importOFXAccount.bind(this), (err, groupedNewRecords) =>
        @newRecords = []
        @newRecords.dryRun = @dryRun
        for group, i in groupedNewRecords
          account = results.accounts[i]
          for record in group
            @newRecords.push _.extend record,
              accountId: account.accountId
        next(err)
    return

  importOFXAccount: (data, done) ->
    {accountId, transactions} = data
    @req.models.TransactionAccount.find(identifier: accountId)
    .first (err, account) =>
      return done err if err
      next = (err) =>
        return done err if err
        account.getTransactions (err, existingTransactions) =>
          return done err if err
          @reconcileTransactions account, existingTransactions, transactions, done
      if !account
        account = new @req.models.TransactionAccount
          name: accountId
          identifier: accountId
        account.save next
      else
        next()

  reconcileTransactions: (account, oldTransactions, newTransactions, done) ->
    newRecords = []
    updatedTransactions = []
    getUniqueTransactionId = (tx, fromOFX = false) ->
      # We can't use this any more because Barclays broke it
      ## tx.fitid
      datesafe = (date) ->
        # All dates fed in represent, roughly, midnight. However their timezones can be weird.
        # To make this safer, we add 12 hours to everything - midday is safer than midnight.
        # This works for So Make It's data from Barclays but may have issues elsewhere - beware.
        twelveHours = 12 * 60 * 60 * 1000
        d = new Date(+date + twelveHours)
        return d
      if fromOFX
        txDate = tx.date
        txDesc = tx.name
      else
        txDate = tx.when
        txDesc = tx.description
      if txMatches = txDesc.match(/\b(M0[0-9]+)\b/)
        # We can't rely on fitid because Barclays broke it; but also we can't
        # rely on description because that can change from export to export
        # also. So now we just compare the matching part of the transaction
        # description in the hopes that that will be sufficient.
        txDesc = txMatches[1]
      r = "#{datesafe(txDate).toISOString().substr(0, 10)}||#{txDesc}||#{tx.amount}"
      return r

    oldTransactionsByUniqueTransactionId = {}
    for tx in oldTransactions
      oldTransactionsByUniqueTransactionId[getUniqueTransactionId(tx, false)] = tx
    for tx in newTransactions
      oldTransaction = oldTransactionsByUniqueTransactionId[getUniqueTransactionId(tx, true)]
      if oldTransaction
        # Can't do this any more because Barclays broke FITIDs
        ## # Check details 
        ## if oldTransaction.when.toISOString().substr(0, 10) isnt tx.date.toISOString().substr(0, 10)
        ##   oldTransaction.when = tx.date
        ##   updatedTransactions.push oldTransaction
        continue
      newRecordData =
        transaction_account_id: account.id
        fitid: tx.fitid
        when: tx.date
        type: tx.type
        description: tx.name
        amount: tx.amount
      newRecords.push newRecordData
    if @dryRun
      done(null, newRecords)
    else
      @req.models.Transaction.create newRecords, (err) ->
        return done err if err
        save = (model, next) ->
          model.save next
        async.eachSeries updatedTransactions, save, (err) ->
          return done err if err
          done null, newRecords

  parseOFX: (filename, callback) ->
    regex = /^(.*) M(0[0-9]+) ([A-Z]{3})$/
    fs.readFile filename, 'utf8', (err, ofxData) ->
      if err
        return callback err
      data = ofx.parse ofxData
      STMTTRNRS = data.OFX?.BANKMSGSRSV1?.STMTTRNRS
      STMTTRNRS = [STMTTRNRS] unless Array.isArray STMTTRNRS
      output =
        accounts: []
      for statement in STMTTRNRS
        account =
          accountId: statement.STMTRS.BANKACCTFROM?.ACCTID
          bankId: statement.STMTRS.BANKACCTFROM?.BANKID
          branchId: statement.STMTRS.BANKACCTFROM?.BRANCHID
          accountType: statement.STMTRS.BANKACCTFROM?.ACCTTYPE
          transactions: []
        transactions = account.transactions
        STMTTRN = statement.STMTRS.BANKTRANLIST?.STMTTRN
        STMTTRN = [STMTTRN] unless Array.isArray STMTTRN
        for tx in STMTTRN ? [] when tx
          type = String(tx.TRNTYPE)
          dateString = String(tx.DTPOSTED)
          date = new Date(parseInt(dateString[0..3], 10), parseInt(dateString[4..5], 10) - 1, parseInt(dateString[6..7], 10))
          amount = Math.round(parseFloat(tx.TRNAMT) * 100)
          fitid = String(tx.FITID)
          name = entities.decode String(tx.NAME)
          transactions.push {type, date, amount, fitid, name}
        transactions.sort (a, b) -> a.date - b.date
        output.accounts.push account
      callback null, output

  setActiveNagivationId: ->
    @activeNavigationId = 'members-area-banking'

module.exports = BankingController
