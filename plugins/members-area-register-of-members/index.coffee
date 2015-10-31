module.exports =
  initialize: (done) ->
    @app.addRoute 'all', '/members/register', 'members-area-register-of-members#register#view'
    @app.addRoute 'all', '/settings/register', 'members-area-register-of-members#register#settings'
    @hook 'navigation_items', @modifyNavigationItems.bind(this)
    done()

  modifyNavigationItems: ({addItem}) ->
    addItem 'admin',
      title: 'Register of Members'
      id: 'members-area-register-of-members-register-view'
      href: '/members/register'
      priority: 20
      permissions: ['admin']
    addItem 'settings',
      title: 'Register of Members'
      id: 'members-area-register-of-members-register-settings'
      href: '/settings/register'
      priority: 20
      permissions: ['admin']
    return
