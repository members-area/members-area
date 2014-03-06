LoggedInController = require './logged-in'
_ = require 'underscore'

module.exports = class RoleController extends LoggedInController
  @before 'loadRoles', only: ['index', 'admin', 'edit']
  @before 'ensureAdminRoles', only: ['admin', 'edit']
  @before 'getRole', only: ['edit']
  @before 'generateRequirementTypes', only: ['index', 'edit']

  index: (done) ->
    next = =>
      @req.user.getRoleUsers (err, roleUsers) =>
        return done err if err
        @activeRoleIds = (roleUser.role_id for roleUser in roleUsers when roleUser.approved? and !roleUser.rejected?)
        @appliedRoleIds = (roleUser.role_id for roleUser in roleUsers when !roleUser.approved? and !roleUser.rejected?)
        @eligibleRoleIds = (role.id for role in @roles) # XXX: improve this!
        done()
    if @req.method is 'POST' and @req.body.role_id?
      roleId = parseInt(@req.body.role_id, 10)
      @req.user.requestRoles [roleId], (err) ->
        return done err if err
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
      .run (err, users) =>
        return done err if err
        for roleUser in @roleUsers
          for user in users when user.id is roleUser.user_id
            roleUser.user = user
            break
        done()

  application: (done) ->
    @activeNavigationId = "role-applications"
    @req.models.RoleUser.get @req.params.id, (err, @roleUser) =>
      return done err if err
      @role = @roleUser.role
      @req.models.User.get @roleUser.user_id, (err, @user) =>
        return done err if err
        done()

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
        requirement =
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
