PersonController = require 'members-area/app/controllers/person'
bcrypt = require 'members-area/node_modules/bcrypt'

lpad = (id) ->
  r = String(id)
  while r.length < 4
    r = "0#{r}"
  return r

module.exports =
  initialize: (done) ->
    @app.addRoute 'all' , '/pincodes' , 'members-area-pin-codes#pin-codes#list'
    @app.addRoute 'all', '/settings/pin-codes', 'members-area-pin-codes#pin-codes#settings'
    @app.addRoute 'post' , '/pincodes/open' , 'members-area-pin-codes#pin-codes#open'
    @hook 'render-person-view' , @modifyUserPage.bind(this)
    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'models:initialize', ({models}) =>
      models.Pinentry.hasOne 'user', models.User, reverse: 'pinentry'
    PersonController.before @processPin, only: ['view']
    done()

  modifyUserPage: (options, done) ->
    {controller, $} = options
    isMe = controller.user.id is controller.loggedInUser.id
    return done() unless controller.loggedInUser.can('admin') or isMe

    #Get meta for currently selected user (not request user)
    hasCode = controller.user.meta.pincode?

    message =
      if hasCode
        "<p class='text-success'>#{if isMe then "You have a PIN code set." else "Has a PIN code set"}</p>"
      else
        "<p class='text-warning'>#{if isMe then "You've not got a PIN code set yet, please set one up below" else "Has no PIN code set"}</p>"

    htmlToAdd = """
      <h3>Manage PIN Code</h3>
      #{message}
      """

    if isMe
      if hasCode
        htmlToAdd += """
          <p>Your 12-digit PIN is the 4 fixed digits followed by the 8 digits you chose</p>
          """
        if controller.revealPin
          htmlToAdd += """
            <p class="text-info" style="font-size: 2em; font-weight: bold;">PIN: #{controller.user.meta.pincode.replace(/^(....)/, "$1 ")}</p>
            """
        else
          htmlToAdd += """
            <form method='POST' class='form-horizontal'>
              <input type='hidden' name='revealPin' value='pin'>
              <button type="submit" class="btn btn-warning">Click here to reveal your full PIN code</button>
            </form>
            """
      htmlToAdd += """
        <form method='POST' class='form-horizontal'>
          <h4>Update PIN code</h4>
          <input type='hidden' name='replacePin' value='pin'>
          <div class="control-group">
            <label class="control-label">4 fixed digits</label>
            <div class="controls">
              <input type="text" readonly value="#{lpad(controller.user.id)}">
            </div>
          </div>
          <div class="control-group">
            <label for="pin" class="control-label">8 custom digits</label>
            <div class="controls">
              <input id="pin" name="pin" length=8 placeholder="00000000"><br />
              #{if controller.pinError then "<p class='text-error'>#{controller.pinError}</p>" else ""}
            </div>
          </div>
          <div class="control-group">
            <label for="pin" class="control-label">Show full PIN on save</label>
            <div class="controls">
              <input name="revealPin" value="pin" type="checkbox" checked />
            </div>
          </div>
          <div class="control-group">
            <div class="controls">
              <button type="Submit" class="btn-success">Update</button>
            </div>
          </div>
        </form>
        """

    $(".main").append htmlToAdd

    done()

  processPin: (done) ->
    return done() unless @user.id is @loggedInUser.id
    if @req.method is 'POST' and @req.body.revealPin is 'pin'
      @revealPin = true
    if @req.method is 'POST' and @req.body.replacePin is 'pin'
      newPin = String(@req.body.pin)
      if newPin.match /^[0-9]{8}$/

        fullPin = lpad(@user.id) + newPin

        bcrypt.hash fullPin, 10, (err, hash) =>
          return done err if err
          @user.setMeta
            pincode: fullPin
            hashedPincode: hash
          @user.save done
      else
        @pinError = "Invalid pin code (must be 8 digits long)"
        done()
    else
      done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'settings',
      title: 'PIN codes'
      id: 'members-area-pin-codes-pin-codes-settings'
      href: '/settings/pin-codes'
      priority: 20
      permissions: ['admin']
    return
