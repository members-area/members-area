RoleController = require 'members-area/app/controllers/role'
PersonController = require 'members-area/app/controllers/person'
encode = require('entities').encodeXML

module.exports =
  customPaymentMethods:
    CASH: "Cash"
    PAYPAL: "PayPal"
    OTHER: "Other"

  initialize: (done) ->
    @app.addRoute 'all', '/admin/payments', 'members-area-payments#payments#index'
    @app.addRoute 'all', '/admin/payments/:id', 'members-area-payments#payments#view'
    @app.addRoute 'all', '/subscription', 'members-area-payments#subscription#view'

    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'models:initialize', ({models}) =>
      models.Payment.hasOne 'transaction', models.Transaction, reverse: 'payments', autoFetch: false
      models.Payment.hasOne 'user', models.User, reverse: 'payments', autoFetch: false
    @hook 'render-role-edit', @renderRoleSubscription.bind(this)
    @hook 'render-person-view', @renderPersonPayments.bind(this)
    @hook 'render-person-index', @renderPersonIndex.bind(this)

    RoleController.before @handleRoleSubscription, only: ['edit']
    PersonController.before @addPaidUntilClasses, only: ['index']
    PersonController.before @addPayment(@customPaymentMethods), only: ['view']

    @addCSS "#{__dirname}/css/payments.styl"

    done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'user',
      title: 'Subscription'
      id: 'members-area-payments-subscription-view'
      href: '/subscription'
      permissions: []
      priority: 42
    addItem 'admin',
      title: 'Payments'
      id: 'members-area-payments'
      href: '/admin/payments'
      permissions: ['admin']
      priority: 20

  renderRoleSubscription: (options) ->
    {controller, $} = options
    $topNode = $('.main form').first().find('.form-group').last()
    checked = if !!controller.role.meta.subscriptionRequired then " checked='checked'" else ""
    $newNode = $ """
      <div class="form-group">
        <label for="name" class="control-label">Subscription required</label>
        <div class="controls">
          <input type="checkbox" name="subscriptionRequired"#{checked}> Check this if a subscription is required from people with this role.
        </div>
      </div>
      """
    $topNode.before $newNode
    return

  addPayment: (customPaymentMethods) -> (done) ->
    # IMPORTANT: this method runs in the context of a PersonController instance
    return done() unless @req.method is 'POST' and @req.body?.action is 'add-payment'
    return done() unless @loggedInUser.can 'admin'
    return done new Error("Invalid YYYY-MM-DD date '#{@req.body.when}'") unless /^201[4-9]-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/.test @req.body.when
    return done new Error("Invalid type '#{@req.body.type}'") unless customPaymentMethods[@req.body.type]
    periodCount = parseInt(@req.body.period_count, 10)
    return done new Error("Invalid period count '#{@req.body.period_count}'") unless 1 <= periodCount <= 12

    paidWhen = new Date(Date.parse(@req.body.when))
    nextPaymentDate = @user.getPaidUntil paidWhen

    payment =
      user_id: @user.id
      type: @req.body.type
      amount: Math.round(parseFloat(@req.body.amount) * 100)
      status: 'paid'
      include: true
      when: paidWhen
      period_from: nextPaymentDate
      period_count: periodCount

    nextPaymentDate = new Date(+nextPaymentDate)
    nextPaymentDate.setMonth(nextPaymentDate.getMonth() + periodCount)
    @user.paidUntil = nextPaymentDate

    @req.models.Payment.create [payment], (err) =>
      return done err if err
      @user.save done

  renderPersonIndex: (options, done) ->
    {controller, $} = options
    return done() unless controller.loggedInUser.can 'admin'
    $main = $("#main.container").eq(0)

    map =
      good: "<4 days overdue"
      warning: "<30 days overdue"
      severeWarning: "<90 days overdue"
      error: "Massively overdue"
      supporter: "Recent supporter"
      none: "No subs required"
    rows = []
    for k, v of map
      rows.push """
        <tr>
          <td>#{encode v}</td>
          <td>#{controller.subscriptionStats[k]}</td>
        </tr>
        """
    $main.append """
      <table style="width: 30%" class="table">
        <tr>
          <th>Subscription status</th>
          <th>Count</th>
        </tr>
        #{rows.join("")}
      </table>
      """
    done()
    return


  renderPersonPayments: (options, done) ->
    {controller, $} = options
    return done() unless controller.loggedInUser.can 'admin'
    controller.req.models.Payment.find()
    .order("-when")
    .where(user_id: controller.user.id)
    .limit(20)
    .run (err, payments) =>
      $main = $("#main.container").eq(0)

      rows = []
      if payments?.length
        for payment in payments
          worked = payment.period_count isnt 0 and payment.include
          rows.push """
            <tr class="#{if worked then "" else "text-error"}">
              <td><a href="/admin/payments/#{payment.id}">#{payment.when.toISOString().substr(0, 10)}</a></td>
              <td>#{payment.type}</td>
              <td>£#{(payment.amount/100).toFixed(2)}</td>
              <td>#{payment.period_from.toISOString().substr(0, 10)}</td>
              <td>#{if payment.period_count == 0 then "[removed]" else payment.period_count}</td>
              <td>#{if worked then "✔" else "✘"}</td>
            </tr>
            """
      else
        rows.push """
          <tr>
            <td colspan="6">
              No records to display
            </td>
          </tr>
          """

      paidUntil = controller.user.paidUntil

      midnightThisMorning = new Date()
      midnightThisMorning.setHours(0)
      midnightThisMorning.setMinutes(0)
      midnightThisMorning.setSeconds(0)

      midnightAMonthAgo = new Date +midnightThisMorning
      midnightAMonthAgo.setMonth(midnightAMonthAgo.getMonth()-1)

      overdueDays = Math.floor (midnightThisMorning - paidUntil)/(24*60*60*1000)

      statusText =
        if +paidUntil > +midnightThisMorning
          "<p class='text-success'>Payments up to date (next due: #{paidUntil.toISOString().substr(0,10)})</p>"
        else if +paidUntil > midnightAMonthAgo
          "<p class='text-warning'>Payments #{overdueDays} days overdue</p>"
        else
          "<p class='text-error'>Payments #{Math.floor overdueDays/7} weeks overdue</p>"

      $main.append """
        <h3>Add a Payment</h3>
        <form method="POST">
          <fieldset>
            <table class="table table-bordered" style="width: auto">
              <tr>
                <th>Payment type</th>
                <td>
                  <div class="form-group">
                    <select name='type'>
                      #{
                        (for k, v of @customPaymentMethods
                          "<option value='#{k}'>#{v}</option>"
                        ).join("\n")
                      }
                    </select>
                  </div>
                </td>
              </tr>
              <tr>
                <th>
                  Payment date<br>
                  <small>(YYYY-MM-DD)</small>
                </th>
                <td>
                  <div class='form-group'>
                    <input class='form-control' name='when' placeholder='YYYY-MM-DD' value='#{new Date().toISOString().substr(0,10)}'>
                  </div>
                </td>
              </tr>
              <tr>
                <th>
                  Amount<br>
                  <small>£ (GBP)</small>
                </th>
                <td>
                  <div class='form-group'>
                    <input class='form-control' name='amount' value='5.00'>
                  </div>
                </td>
              </tr>
              <tr>
                <th>
                  Duration<br>
                  <small>(months, the period covered by the payment)
                </th>
                <td>
                  <div class='form-group'>
                    <select name='period_count'>
                      <option value='1' selected='selected'>1 month</option>
                      <option value='2'>2 months</option>
                      <option value='3'>3 months</option>
                      <option value='4'>4 months</option>
                      <option value='5'>5 months</option>
                      <option value='6'>6 months</option>
                      <option value='7'>7 months</option>
                      <option value='8'>8 months</option>
                      <option value='9'>9 months</option>
                      <option value='10'>10 months</option>
                      <option value='11'>11 months</option>
                      <option value='12'>12 months</option>
                    </select>
                  </div>
                </td>
              </tr>
            </table>
          <fieldset>
          <button class='btn btn-primary btn-warning' type='submit' name='action' value='add-payment'>
            Register payment
          </button>
        </form>
        <h3>Payments</h3>
        #{statusText}
        <table class="table table-striped">
          <tr>
            <th>Payment Date</th>
            <th>Type</th>
            <th>Amount</th>
            <th>From</th>
            <th>Duration (months)</th>
            <th>Worked?</th>
          </tr>
          #{rows.join("\n")}
        </table>
        """
      done()
      return

  handleRoleSubscription: ->
    # IMPORTANT: this method runs in the context of a RoleController instance
    if @req.method is 'POST' and !@data.action
      subscriptionRequired = !!@data.subscriptionRequired
      delete @data.subscriptionRequired
      @role.setMeta {subscriptionRequired}

  addPaidUntilClasses: ->
    # IMPORTANT: this method runs in the context of a RoleController instance
    return unless @isAdmin

    midnightThisMorning = new Date()
    midnightThisMorning.setHours(0)
    midnightThisMorning.setMinutes(0)
    midnightThisMorning.setSeconds(0)

    twentyDaysAgo = new Date()
    twentyDaysAgo.setDate(twentyDaysAgo.getDate() - 20)

    @subscriptionStats =
      none: 0
      supporter: 0
      good: 0
      warning: 0
      severeWarning: 0
      error: 0

    for user in @users
      overdueDays = Math.floor (midnightThisMorning - user.paidUntil)/(24*60*60*1000)
      if overdueDays <= 3
        user.classNames += " payments-good"
        if user.subscriptionRequired
          @subscriptionStats.good++
        else if (midnightThisMorning - user.getPaidUntil(twentyDaysAgo)) / (24*60*60*1000) <= 14
          @subscriptionStats.supporter++
        else
          @subscriptionStats.none++
      else if overdueDays < 30
        user.classNames += " payments-warning"
        @subscriptionStats.warning++
      else if overdueDays < 90
        user.classNames += " payments-severe-warning"
        @subscriptionStats.severeWarning++
      else
        user.classNames += " payments-error"
        @subscriptionStats.error++
