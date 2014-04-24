_ = require 'underscore'
async = require 'async'

cloneCallbacks = (oldCallbacks = {}) ->
  result = {}
  for key of oldCallbacks
    result[key] = (oldCallbacks[key] ? []).slice()
  return result

class Controller
  @makeCallbacksLocal: ->
    clonedCallbacksProperty = "#{@name}_callbacks_cloned"
    unless @hasOwnProperty(clonedCallbacksProperty)
      @_callbacks = cloneCallbacks @_callbacks
      @[clonedCallbacksProperty] = true
    return

  @callback: (event, method, options = {}) ->
    @makeCallbacksLocal()
    options.only = [options.only] if options.only? and !Array.isArray(options.only)
    options.except = [options.except] if options.except? and !Array.isArray(options.except)
    @_callbacks[event] ?= []
    @_callbacks[event].push method: method, options: options
    return

  @callbacks: (event) ->
    @makeCallbacksLocal()
    (@_callbacks[event] ? []).slice()

  @before: -> @callback 'before', arguments...
  @after: -> @callback 'after', arguments...

  @handle: (params, req, res, next) ->
    {action} = params
    return next new req.HTTPError 404, "'#{params.controller}' controller has no '#{action}' method" unless @prototype[action]

    instance = new this req.app, params, req, res

    array = @callbacks('before')
    array = array.concat(action)
    array = array.concat('generateNav')
    array = array.concat('render')
    #array = array.concat @callbacks('after')

    run = (entry, done) ->
      try
        return done() if instance.rendered
        if typeof entry is 'string'
          entry = method: entry, options: {}
        return done() if entry.options.only and action not in entry.options.only
        return done() if entry.options.except and action in entry.options.except
        fn = entry.method
        fn = instance[fn] if typeof fn is 'string'
        unless fn
          throw new Error "#{params.controller} has no method #{entry.method}"
        if fn.length > 0
          fn.call instance, done
        else
          fn.call instance
          process.nextTick done
      catch e
        next e

    async.eachSeries array, run, (err) =>
      next err unless instance.rendered

  constructor: (@app, @params, @req, @res) ->
    if @params.plugin
      @plugin = @app.getPlugin(@params.plugin)
      @templateParent ?= "#{@plugin.path}/views/#{@params.controller}"
    else
      @templateParent ?= @params.controller
    @template ?= @params.action
    @data = @req.body ? {}
    @title = "Members Area"
    @loggedInUser = @req.user

  render: (done) ->
    return if @rendered
    vars = {}
    vars[k] = v for own k, v of @ when typeof k isnt 'function'
    @res.render "#{@templateParent}/#{@template}", vars, (err, html) =>
      return done err if err
      options = {controller: this, html: html}
      psn = "-#{@plugin.shortName}" if @plugin
      @req.app.pluginHook "render render#{psn ? ""}-#{@params.controller}-#{@template}", options, =>
        @rendered = true
        @res.send options.html
        done()

  redirectTo: (url, {status} = {}) ->
    return if @rendered
    if status?
      @res.redirect status, url
    else
      @res.redirect url
    @rendered = true

  generateNav: (done) ->
    @loggedInUser = @req.user # Update in case this changed
    return done() unless @req.user?
    unless @activeNavigationId
      @activeNavigationId = "#{@params.controller}-#{@params.action}"
      @activeNavigationId = "#{@params.plugin}-#{@activeNavigationId}" if @params.plugin

    sections = [
      {
        title: @req.user.fullname
        id: 'user'
        priority: 10
        items: [
          {
            title: 'Dashboard'
            href: '/dashboard'
            id: 'user-dashboard'
            priority: 10
          }
          {
            title: 'Account'
            href: '/account'
            id: 'user-account'
            priority: 50
          }
          {
            title: 'People'
            href: '/people'
            id: 'person-index'
            priority: 100
          }
        ]
      }
      {
        title: 'Roles'
        id: 'roles'
        priority: 50
        items: [
          {
            title: 'Apply'
            href: '/roles'
            id: 'role-index'
            priority: 10
          }
          {
            title: 'Applications'
            href: '/roles/applications'
            id: 'role-applications'
            priority: 100
          }
        ]
      }
      {
        title: 'Admin'
        id: 'admin'
        priority: 100
        items: []
      }
      {
        title: 'Settings'
        id: 'settings'
        priority: 200
        items: [
          {
            title: 'Core Settings'
            href: '/settings'
            id: 'admin-settings'
            priority: 10
            permissions: ['root']
          }
          {
            title: 'Roles'
            href: '/settings/roles'
            id: 'role-admin'
            priority: 20
            permissions: ['admin_roles']
          }
        ]
      }
      {
        title: 'Other'
        id: ''
        priority: 1000
      }
    ]

    addSection = (section) ->
      # XXX: check for duplicate id?
      sections.push section

    addItem = (sectionId, item) ->
      for section in sections when section.id is sectionId
        section.items ?= []
        section.items.push item
        return
      addItem '', item

    sorter = (a, b) ->
      if a.priority < b.priority
        -1
      else if a.priority > b.priority
        1
      else
        a.title.localeCompare(b.title)

    async.series [
      (next) =>
        @req.app.pluginHook 'navigation_sections', {sections, addSection}, next

      (next) =>
        sections.sort(sorter)
        next()

      (next) =>
        @req.app.pluginHook 'navigation_items', {sections, addItem}, next

      (next) =>
        for section in sections
          section.header = true
          section.items ?= []
          section.items.sort(sorter)
        next()

      (next) =>
        @req.app.pluginHook 'navigation', {sections}, next
    ], =>
      # Prune by permissions
      for section in sections
        for item, i in section.items ? [] by -1
          section.items.splice(i, 1) unless @req.user.can item.permissions

      # Prune empty items
      for section, i in sections by -1
        sections.splice(i, 1) unless section.items?.length

      @navigation = sections

      # Find active link
      for section in @navigation
        for item in section.items
          if item.id is @activeNavigationId
            item.active = true
            break

      done()

  baseURL: ->
    "#{@req.protocol}://#{@req.header('host')}"

module.exports = Controller
