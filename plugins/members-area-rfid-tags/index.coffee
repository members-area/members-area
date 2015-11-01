PersonController = require 'members-area/app/controllers/person'
bcrypt = require 'bcrypt'

lpad = (id) ->
  r = String(id)
  while r.length < 4
    r = "0#{r}"
  return r

module.exports =
  initialize: (done) ->
    @app.addRoute 'all' , '/rfid-tags' , 'members-area-rfid-tags#rfid-tags#list'
    @app.addRoute 'all', '/settings/rfid-tags', 'members-area-rfid-tags#rfid-tags#settings'
    @app.addRoute 'post' , '/rfid-tags/open' , 'members-area-rfid-tags#rfid-tags#open'
    @hook 'render-person-view' , @modifyUserPage.bind(this)
    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    @hook 'models:initialize', ({models}) =>
      models.Rfidtag.hasOne 'user', models.User, reverse: 'rfidtags'
    done()

  modifyUserPage: (options, done) ->
    {controller, $} = options
    isMe = controller.user.id is controller.loggedInUser.id
    return done() unless controller.loggedInUser.can('admin') or isMe

    rfidtags = controller.user.getRfidtags().run (err, rfidtags) ->
      message =
        if rfidtags.length
          "<p class='text-success'>#{if isMe then "You have" else "Has"} #{rfidtags.length} RFID tag#{if rfidtags.length is 1 then "" else "s"}</p>"
        else
          "<p class='text-warning'>#{if isMe then "You've not got any RFID tags yet" else "Has no RFID tags"}</p>"

      htmlToAdd = """
        <h3>Manage RFID tags</h3>
        #{message}
        """

      if rfidtags.length
        htmlToAdd += "<ul>"
        for tag in rfidtags
          htmlToAdd += "<li>#{tag.uid}</li>"
        htmlToAdd += "</ul>"

      $(".main").append htmlToAdd

      done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'settings',
      title: 'RFID tags'
      id: 'members-area-rfid-tags-rfid-tags-settings'
      href: '/settings/rfid-tags'
      priority: 20
      permissions: ['admin']
    return
