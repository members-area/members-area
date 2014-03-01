_ = require 'underscore'
async = require 'async'

cloneCallbacks = (oldCallbacks = {}) ->
  result = {}
  for key of oldCallbacks
    result = (oldCallbacks[key] ? []).slice()
  return result

class Controller
  @makeCallbacksLocal: ->
    unless @hasOwnProperty('_callbacks')
      @_callbacks = cloneCallbacks @_callbacks
    return

  @callback: (event, method, options = {}) ->
    @makeCallbacksLocal()
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
        fn = instance[entry.method]
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
      @templateParent ?= "#{@app.path}/plugins/#{@params.plugin}/views/#{@params.controller}"
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
      @req.app.pluginHook "render render-#{@templateParent}-#{@template}", options, =>
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
    return done() unless @req.user?
    # XXX: Get additional nav items from plugins
    @activeNavigationId ?= "#{@templateParent}-#{@template}"


    sections = [
      {
        title: @req.user.fullname
        id: 'user'
        priority: 10
        items: [
          {
            title: 'Dashbard'
            href: '/dashboard'
            id: 'user-dashboard'
            priority: 10
          }
          {
            title: 'Member list'
            href: '/members'
            id: 'members-index'
            priority: 100
          }
        ]
      }
      {
        title: 'Admin'
        id: 'admin'
        priority: 100
        items: [
          {
            title: 'Register of Members'
            href: '/admin/register'
            id: 'admin-register'
            priority: 100
          }
        ]
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
          items.splice(i, 1) unless @req.user.can item.permissions

      # Prune empty items
      for section, i in sections by -1
        sections.splice(i, 1) unless section.items?.length

      @navigation = sections

      # Find active link
      for item in @navigation
        if item.id is @activeNavigationId
          item.active = true
          break

      done()

module.exports = Controller
