encode = require('entities').encodeXML
getModelsForConnection = require('members-area/app/models')
orm = getModelsForConnection.orm
Reprocessor = require './reprocessor'

createNewBillsInProgress = false

module.exports =
  initialize: (done) ->
    @app.addRoute 'all', '/admin/gocardless', 'members-area-gocardless#gocardless#admin'
    @app.addRoute 'all', '/admin/gocardless/subscriptions', 'members-area-gocardless#gocardless#subscriptions'
    @app.addRoute 'all', '/admin/gocardless/payouts', 'members-area-gocardless#gocardless#payouts'
    @app.addRoute 'all', '/admin/gocardless/bills', 'members-area-gocardless#gocardless#bills'
    @app.addRoute 'all', '/admin/gocardless/preauths', 'members-area-gocardless#gocardless#preauths'
    @app.addRoute 'all', '/admin/gocardless/preauths/dr', 'members-area-gocardless#gocardless#dr_preauths'
    @app.addRoute 'all', '/admin/gocardless/preauths/do', 'members-area-gocardless#gocardless#do_preauths'
    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'render-payments-subscription-view', @renderSubscriptionView.bind(this)
    paymentsPlugin = @app.getPlugin("members-area-payments")
    if paymentsPlugin
      SubscriptionController = require "#{paymentsPlugin.path}/controllers/subscription"
      self = this
      wrapSelf = (fn) ->
        (callback) ->
          fn.call self, this, callback
      SubscriptionController.before wrapSelf(@gocardlessPaymentsCallback), only: ["view"]
      SubscriptionController.before wrapSelf(@setUpGocardlessPayments), only: ["view"]

    # Automatically create new bills every 24 hours
    setInterval @createNewBills.bind(this), (24*60*60*1000)
    # And 12 hours later reprocess the bills
    setTimeout =>
      setInterval @reprocess.bind(this), (24*60*60*1000)
      @reprocess()
    , (2*60*60*1000)
    done()

  reprocess: ->
    orm.connect process.env.DATABASE_URL, (err, db) =>
      getModelsForConnection @app, db, (err, models) =>
        options =
          models: models
          plugin: @
        reprocessor = new Reprocessor options
        console.log "[#{new Date().toISOString()}] STARTING AUTOMATIC GOCARDLESS REPROCESSING"
        reprocessor.reprocess (err) ->
          console.error err if err
          console.log "[#{new Date().toISOString()}] AUTOMATIC GOCARDLESS REPROCESSING FINISHED"
          db.close()

  createNewBills: (options = {}, callback = ->) ->
    orm.connect process.env.DATABASE_URL, (err, db) =>
      done = (err) ->
        console.error err if err
        console.log "[#{new Date().toISOString()}] AUTOMATIC GOCARDLESS BILL CREATION FINISHED"
        db.close()
        callback.apply this, arguments
      console.log "[#{new Date().toISOString()}] STARTING AUTOMATIC GOCARDLESS BILL CREATION"
      getModelsForConnection @app, db, (err, models) =>
        @createNewBillsWithModels(models, options, done)

  createNewBillsWithModels: (models, options, callback) ->
    doIt = =>
      if createNewBillsInProgress
        setTimeout doIt, 200
      else
        createNewBillsInProgress = true
        @_createNewBillsWithModels models, options, ->
          createNewBillsInProgress = false
          callback.apply this, arguments
    doIt()

  _createNewBillsWithModels: (models, options, callback) ->
    if typeof options is 'function'
      callback = options
      options = {}
    @_.defaults options, dryRun: false
    gocardlessClient = require('gocardless')(@get())
    results = []
    @async.auto
      users: (done) ->
        models.User.all done
      preauths: (done) ->
        gocardlessClient.preAuthorization.index (err, res, body) ->
          try
            body = JSON.parse body if typeof body is 'string'
            throw new Error(body.error.join(" \n")) if body.error
            body = body.filter (e) -> e.status is 'active'
          catch e
            err ?= e
          done(err, body)
      bills: (done) ->
        gocardlessClient.bill.index (err, res, body) ->
          try
            body = JSON.parse body if typeof body is 'string'
            throw new Error(body.error.join(" \n")) if body.error
          catch e
            err ?= e
          # XXX: filter out failed/cancelled bills
          done(err, body)
      newBills: ['users', 'preauths', 'bills', (done, {users, preauths, bills}) ->
        newBills = []
        usersById = {}
        usersById[user.id] = user for user in users
        billByUserId = {}
        for bill in bills when bill.source_type is 'pre_authorization' and (bill.status not in ['cancelled', 'failed'])
          bill.preauth = p for p in preauths when p.id is bill.source_id
          if bill.preauth?.name.match /^M[0-9]+$/
            user_id = parseInt(bill.preauth.name.substr(1), 10)
            oldBill = billByUserId[user_id]
            billByUserId[user_id] = bill if !oldBill or Date.parse(oldBill.created_at) < Date.parse(bill.created_at)
        today = new Date()
        today.setHours(0)
        today.setMinutes(0)
        today.setSeconds(0)
        tomorrow = new Date(+today)
        tomorrow.setDate(tomorrow.getDate()+1)
        threeWeeksAgo = new Date(+today)
        threeWeeksAgo.setDate(threeWeeksAgo.getDate() - (7*3))
        oneWeekHence = new Date(+today)
        oneWeekHence.setDate(oneWeekHence.getDate() + 7)
        for preauth in preauths when preauth.name.match /^M[0-9]+$/
          user_id = parseInt(preauth.name.substr(1), 10)
          bill = billByUserId[user_id]
          user = usersById[user_id]
          unless user.meta.gocardless
            console.error "ERROR: there's a pre-auth configured for user #{user.id} but they have no GoCardless settings!"
            continue
          amount = parseFloat(user.meta.gocardless.monthly)
          unless amount > 0
            console.error "ERROR: user #{user.id} has no configured monthly payment"
            continue
          # We only want to make the bill about a week in advance
          if bill and (bill.status is 'pending' or Date.parse(bill.created_at) > +threeWeeksAgo)
            # In the interests of self healing, make sure paidInitial is true
            unless user.meta.gocardless.paidInitial
              console.error "WARNING: Had to set paidInitial for #{user.id} after the fact"
              gocardless = user.meta.gocardless
              gocardless.paidInitial = true
              user.setMeta gocardless: gocardless
              user.save ->
            continue
          dayPreference = user.meta.gocardless.dayOfMonth
          billDate = new Date(+tomorrow)
          billDate.setDate(parseInt(dayPreference, 10) || 1)
          billDate.setMonth(billDate.getMonth()+1) if +billDate < +tomorrow
          continue if +billDate > +oneWeekHence
          unless user.meta.gocardless.paidInitial
            amount += parseFloat(user.meta.gocardless.initial)
          amount *= 1.01 # Add the GoCardless fee
          bill =
            pre_authorization_id: preauth.id
            amount: "#{amount.toFixed(2)}"
            name: 'Monthly subscription'
            charge_customer_at: billDate.toISOString().substr(0, 10)
          newBills.push {user, bill}
        done(null, newBills)
      ]
      createdBills: ['newBills', (done, {newBills}) =>
        if options.dryRun
          newBills.dryRun = true
          done(null, newBills)
        else
          createBill = ({user, bill}, next) ->
            gocardlessClient.bill.create bill, (err, response, body) ->
              try
                body = JSON.parse body if typeof body is 'string'
                throw new Error(body.error.join(" \n")) if body.error
              catch e
                err = e
              if err
                console.error "ERROR creating bill in GoCardless"
                console.dir err
              bill.error = err if err
              next(null, {user, bill})
          @async.mapSeries newBills, createBill, done
      ]

    , (err, results) ->
      callback(err, results.createdBills)

  gocardlessPaymentsCallback: (controller, callback) ->
    loggedInUser = controller.loggedInUser

    req = controller.req
    if req.method is 'GET' and req.query.signature and req.query.resource_uri and req.query.resource_id and req.query.resource_type is "pre_authorization" and req.query.state is String(loggedInUser.id) and loggedInUser.meta.gocardless
      # This looks like a valid gocardless callback!
      gocardlessClient = require('gocardless')(@get())
      gocardlessClient.confirmResource req.query, (err, request, body) =>
        try
          body = JSON.parse body if typeof body is 'string'
          throw new Error(body.error.join(" \n")) if body.error
        catch e
          err ?= e
        return callback err if err
        # SUCCESS!
        gocardless = loggedInUser.meta.gocardless ? {}
        gocardless.resource_id = req.query.resource_id
        loggedInUser.setMeta gocardless: gocardless
        loggedInUser.save =>
          controller.redirectTo "/subscription"
          callback()
    else
      return callback()

  setUpGocardlessPayments: (controller, callback) ->
    loggedInUser = controller.loggedInUser
    controller.data.dom ?= loggedInUser.meta.gocardless?.dayOfMonth ? new Date().getDate() + 1
    controller.data.monthly ?= loggedInUser.meta.gocardless?.monthly
    controller.data.initial ?= loggedInUser.meta.gocardless?.initial
    return callback() unless controller.req.method is 'POST' and controller.req.body?.form is "gocardless"
    {dom, monthly, initial} = controller.req.body
    console.log "Charge me £#{initial} up front followed by £#{monthly} per month on the #{dom} day of the month"
    initial = parseFloat initial
    monthly = parseFloat monthly
    dom = parseInt dom, 10

    min_amount = @get('min_amount') ? 5
    error = false
    if !isFinite(initial) or initial > 500
      controller.error_initial = "Please enter a sensible number of pounds and pence"
      error = true
    if !isFinite(monthly) or monthly > 200
      controller.error_monthly = "Please enter a sensible number of pounds and pence"
      error = true
    if monthly < min_amount
      controller.error_monthly = "Minimum monthly payment is £#{min_amount.toFixed(2)}"
      error = true
    if !isFinite(dom) or not (0 < dom < 29)
      controller.error_dom = "Please pick a day of the month"
      error = true

    return callback() if error
    initial = initial.toFixed(2)
    monthly = monthly.toFixed(2)

    gocardless = loggedInUser.meta.gocardless ? {}
    gocardless.initial = initial
    gocardless.monthly = monthly
    gocardless.dayOfMonth = dom
    loggedInUser.setMeta gocardless: gocardless
    loggedInUser.save =>
      return callback() if gocardless.resource_id # Subscription already set up
      max = parseFloat(@get('max_amount') ? 250)
      if max < parseFloat(initial) + parseFloat(monthly)
        max = (parseFloat(initial) + parseFloat(monthly)) * 2

      # Guess at some stuff to prefill for them
      tmp = loggedInUser.fullname.split(" ")
      firstName = tmp[0]
      lastName = tmp[tmp.length-1]
      address = loggedInUser.address
      if address?.length
        tmp = address.match /[A-Z]{2}[0-9]{1,2}\s*[0-9][A-Z]{2}/i
        if tmp
          postcode = tmp[0].toUpperCase()
          address = address.replace(tmp[0], "")
        tmp = address.split /[\n\r,]/
        tmp = tmp.filter (a) -> a.replace(/\s+/g, "").length > 0
        tmp = tmp.filter (a) -> !a.match /^(hants|hampshire)$/
        for potentialTown, i in tmp
          t = potentialTown.replace /[^a-z]/gi, ""
          if t.match /^(southampton|soton|eastleigh|chandlersford|winchester|northbaddesley|havant|portsmouth|bournemouth|poole|bognorregis|romsey|lyndhurst|eye|warsash|lymington)$/i
            town = potentialTown
            tmp.splice i, 1
            break
        if tmp.length > 1
          address2 = tmp.pop()
        address1 = tmp.join(", ")
      town ?= "Southampton"

      gocardlessClient = require('gocardless')(@get())
      url = gocardlessClient.preAuthorization.newUrl
        max_amount: max
        interval_length: 1
        interval_unit: 'month'
        name: "M#{controller.res.locals.pad(loggedInUser.id, 6)}"
        description: "#{controller.app.siteSetting.meta.settings.name ? "Members Area"} subscription"
        redirect_uri: "#{controller.baseURL()}/subscription"
        cancel_uri: "#{controller.baseURL()}/subscription"
        state: loggedInUser.id
        user:
          first_name: firstName ? ""
          last_name: lastName ? ""
          email: loggedInUser.email ? ""
          account_name: loggedInUser.fullname ? ""
          billing_address1: address1 ? ""
          billing_address2: address2 ? ""
          billing_town: town ? ""
          billing_postcode: postcode ? ""
      controller.redirectTo url
      callback()

  modifyNavigationItems: ({addItem}) ->
    addItem 'admin',
      title: 'GoCardless'
      id: 'members-area-gocardless-admin'
      href: '/admin/gocardless'
      permissions: ['admin']
      priority: 53

  renderSubscriptionView: (options) ->
    {controller, $} = options
    checked = ""

    paidUntil = controller.loggedInUser.paidUntil
    counter = new Date()
    counter.setHours(0)
    counter.setMinutes(0)
    monthsOverdue = 0
    while +counter > +paidUntil and monthsOverdue < 6
      monthsOverdue++
      counter.setMonth(counter.getMonth() - 1)

    isSetUp = controller.loggedInUser.meta.gocardless?.resource_id?
    hideIfSetUp = " style='display:none'" if isSetUp
    hideIfSetUp ?= ""
    legacyWarning = ""
    if controller.loggedInUser.meta.gocardless?.subscription_resource_id?
      legacyWarning = "<p class='text-warning'>You might have the old GoCardless integration set up. If you want to move over to the new system (recommended) then you should cancel the subscription from the GoCardless control panel.</p>"
    $newNode = $ """
      <h3>GoCardless</h3>
      #{legacyWarning}
      <p>
        <a href="https://gocardless.com/?r=Z65JVARP&utm_source=website&utm_medium=copy_paste&utm_campaign=referral_scheme_50">GoCardless</a>
        are the next cheapest way to send us money after standing orders/cash.
        They charge just 1% per transaction (e.g. 20p for every £20) and so are
        very affordable.
      </p>
      <p class="text-info">GoCardless collect money via Direct Debit, and so your payments are covered by the Direct Debit Guarantee.</p>
      """ + (if isSetUp then """
      <p class="text-success">Thank you for setting up a GoCardless subscription; you can edit the amount below.</p>
      """ else """
      <p>To get started, just enter your preferred monthly payment amount below:</p>
      """) + """
      <form method="POST" action="">
        <input type="hidden" name="form" value="gocardless">
        <table style="width:auto" class="table table-bordered">
          <tbody>
            <tr#{hideIfSetUp}>
              <th>
                Day of month<br>
                <small>We'll try and make sure payments come out <br />on or around this day each month.</small>
              </th>
              <td>
                <select name="dom">
                  #{("<option value='#{i}'#{if String(i) is String(controller.data.dom) then " selected='selected'" else ""}>#{i}</option>" for i in [1..28]).join("\n")}
                </select>
                #{if controller.error_dom then "<p class='text-error'>#{encode controller.error_dom}</p>" else ""}
              </td>
            </tr>
            <tr>
              <th>Monthly amount, £</th>
              <td>
                <input type="text" name="monthly" value="#{encode String(controller.data.monthly ? "30")}" id="gocardless_monthly"><br>
                <small>(Including the GoCardless fee, this will be £<strong id="gocardless_monthly_inc">?</strong>)</small>
                #{if controller.error_monthly then "<p class='text-error'>#{encode controller.error_monthly}</p>" else ""}
              </td>
            </tr>
            <tr#{hideIfSetUp}>
              <th>
                Initial fee, £<br><small>One-off donation, completely optional.</small><br>
                <small>This will be taken out of your account soon.</small>
              </th>
              <td>
                <input type="text" name="initial" value="#{encode String(controller.data.initial ? "0")}" id="gocardless_initial"><br>
                <small>(Including the GoCardless fee, this will be £<strong id="gocardless_initial_inc">?</strong>)</small>
                #{if controller.error_initial then "<p class='text-error'>#{encode controller.error_initial}</p>" else ""}
              </td>
            </tr>
          </tbody>
        </table>
        <button type="submit" class="btn btn-success btn-lg">#{if isSetUp then "Update payment amount" else "Set up payments"}</button>
      </form>
      <script type="text/javascript">
        (function() {
          var gocardless_monthly = document.getElementById('gocardless_monthly');
          var gocardless_initial = document.getElementById('gocardless_initial');
          var gocardless_monthly_inc = document.getElementById('gocardless_monthly_inc');
          var gocardless_initial_inc = document.getElementById('gocardless_initial_inc');
          var unmodified = #{if controller.req.body?.initial then "false" else "true"};

          gocardless_monthly.addEventListener('change', update_gocardless_monthly_inc, false);
          gocardless_monthly.addEventListener('keyup', update_gocardless_monthly_inc, false);
          gocardless_initial.addEventListener('change', make_modified, false);
          gocardless_initial.addEventListener('change', update_gocardless_initial_inc, false);
          gocardless_initial.addEventListener('keyup', update_gocardless_initial_inc, false);

          function make_modified() {
            unmodified = false;
          }

          function update_gocardless_monthly_inc() {
            if (unmodified) {
              var v = parseFloat(gocardless_monthly.value);
              if (!isNaN(v)) {
                gocardless_initial.value = (v * #{monthsOverdue}).toFixed(2);
                update_gocardless_initial_inc();
              }
            }
            return update_gocardless_a(gocardless_monthly, gocardless_monthly_inc);
          }

          function update_gocardless_initial_inc(e) {
            return update_gocardless_a(gocardless_initial, gocardless_initial_inc);
          }

          function update_gocardless_a(amount, after) {
            var amount = parseFloat(amount.value);
            if (!isNaN(amount)) {
              amount = 100/99 * amount;
              after.textContent = amount.toFixed(2);
            }
          }

          update_gocardless_monthly_inc();
          update_gocardless_initial_inc();
        })();
      </script>

      """
    $("#main.container").append($newNode)
    return
