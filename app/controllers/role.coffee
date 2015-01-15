LoggedInController = require './logged-in'
_ = require 'underscore'
async = require 'async'

module.exports = class RoleController extends LoggedInController
  @before 'setAdmin'
  @before 'loadRoles', only: ['index', 'admin', 'edit']
  @before 'ensureAdminRoles', only: ['admin', 'edit']
  @before 'getRole', only: ['edit']
  @before 'generateRequirementTypes', only: ['index', 'edit', 'application']

  index: (done) ->
    next = =>
      @req.user.getRoleUsers (err, roleUsers) =>
        return done err if err
        @activeRoleIds = (roleUser.role_id for roleUser in roleUsers when roleUser.approved? and !roleUser.rejected?)
        @appliedRoleIds = (roleUser.role_id for roleUser in roleUsers when !roleUser.approved? and !roleUser.rejected?)
        isEligible = (role, next) =>
          role.canApply @req.user, next
        async.filter @roles, isEligible, (@eligibleRoles) =>
          @eligibleRoleIds = (role.id for role in @eligibleRoles)
          done()
    if @req.method is 'POST' and @req.body.role_id?
      roleId = parseInt(@req.body.role_id, 10)
      @req.user.requestRoles [roleId], (err) ->
        # Ignore error
        next()
    else
      next()

  applications: (done) ->
    @req.models.RoleUser.find()
    .where("approved IS NULL AND rejected IS NULL")
    .run (err, @roleUsers) =>
      return done err if err
      userIds = _.uniq (roleUser.user_id for roleUser in @roleUsers)
      return done() if userIds.length is 0
      @req.models.User.find()
      .where(id:userIds)
      .where("verified IS NOT NULL")
      .run (err, users) =>
        return done err if err
        usersById = {}
        usersById[user.id] = user for user in users
        result = []
        for roleUser in @roleUsers
          roleUser.user = usersById[roleUser.user_id]
        @roleUsers = @roleUsers.filter (rU) -> !!rU.user
        getActionable = (roleUser, next) =>
          roleUser.getRequirementsWithStatusForUser @req.user, (err, requirements) =>
            roleUser.actionable = true for requirement in requirements when requirement.actionable
            next(err)
        async.map @roleUsers, getActionable, done

  application: (done) ->
    @activeNavigationId = "role-applications"
    async.series
      getRoleUser: (next) =>
        @req.models.RoleUser.get @req.params.id, (err, @roleUser) =>
          @role = @roleUser?.role
          next(err)

      handlePOST: (next) =>
        return next() unless @req.method is 'POST'
        if @data['approve']
          @roleUser.approve @req.user, @data['approve'], next
        else if @data['reject'] is '1'
          return next() unless @loggedInUser.can('admin')
          options =
            userId: @loggedInUser.id
            reason: @data['reason']
            date: new Date Date.parse @data['date']
          return next() if options.date > +new Date() # XXX: should convert former to midnight
          @roleUser.reject options, next
        else
          next()

      getUser: (next) =>
        @req.models.User.get @roleUser.user_id, (err, @user) =>
          next(err)

      getRequirements: (next) =>
        @roleUser.getRequirementsWithStatusForUser @req.user, (err, @requirements) =>
          next(err)
    , done

  admin: (done) ->
    if @req.method is 'POST' and @data.name?.length
      console.dir("CREATE #{@data.name}")
      role = new @req.models.Role(name:String(@data.name))
      role.save (err, role) =>
        return done err if err
        @redirectTo "/settings/roles/#{role.id}", status: 303
        done()
    else
      done()

  edit: (done) ->
    @activeNavigationId = "role-admin"

    if @req.method is 'POST'
      requirements = @role.meta.requirements[..] ? []
      index = parseInt(@data.index, 10)

      getRequirement = =>
        requirementType = @requirementTypes[@data.type]
        throw new Error "Couldn't find requirement type '#{@data.type}'" unless requirementType
        id = @data.id
        unless id?.length
          if @data.type is 'approval'
            id = @data.roleId
          else
            id = "#{@data.type}-#{Date.now()}"
        requirement =
          id: id
          type: @data.type
        for input in requirementType.inputs
          value = @data[input.name]
          value = input.validator.call(this, value) if input.validator
          requirement[input.name] = value
        return requirement

      if @data.action is 'edit_requirement' and @data.delete is "delete"
        requirements.splice(index, 1) if 0 <= index < requirements.length
        @role.setMeta requirements: requirements

      else if @data.action is 'edit_requirement'
        try
          requirements.splice(index, 1, getRequirement()) if 0 <= index < requirements.length
          @role.setMeta requirements: requirements
        catch e
          console.error "Could not edit requirement because exception occurred:"
          console.error e.stack

      else if @data.action is 'add_requirement'
        try
          requirements.push getRequirement()
          @role.setMeta requirements: requirements
        catch e
          console.error "Could not add requirement because exception occurred:"
          console.error e.stack

      else if @data.name?.length
        @role.name = @data.name
        unless @data.color?[0..0] == "#"
          @data.color = "##{@data.color}"
        unless @data.color?.match /^#[0-9a-fA-F]{3,6}$/
          @data.color = "#aaa"
        @data.color = @data.color.toLowerCase()
        if @data.color.length is 7
          r = parseInt(@data.color[1..2], 16)/255
          g = parseInt(@data.color[3..4], 16)/255
          b = parseInt(@data.color[5..6], 16)/255
        else
          r = parseInt(@data.color[1..1], 16)/255
          g = parseInt(@data.color[2..2], 16)/255
          b = parseInt(@data.color[3..3], 16)/255
        Y = 0.3 * r + 0.59 * g + 0.11 * b
        light = Y >= 0.5
        textColor = if light then "black" else "white"
        @role.setMeta description: @data.description, emailText: @data.emailText, color: @data.color, textColor: textColor
      @data = @role
      @role.save done

    else
      @data = @role
      done()

  #----------------

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)

  ensureAdminRoles: (done) ->
    return done new @req.HTTPError 403, "Permission denied" unless @req.user.can('admin_roles')
    done()

  getRole: (done) ->
    @req.models.Role.get @req.params.role_id, (err, @role) =>
      @role.meta.requirements ?= []
      done err

  generateRequirementTypes: (done) ->
    @req.models.Role.generateRequirementTypes (err, @requirementTypes) =>
      done()

  setAdmin: ->
    @admin = @loggedInUser.can 'admin'
