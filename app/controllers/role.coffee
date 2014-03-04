LoggedInController = require './logged-in'

module.exports = class RoleController extends LoggedInController
  @before 'loadRoles', only: ['index', 'admin', 'edit']
  @before 'ensureAdminRoles', only: ['admin', 'edit']
  @before 'getRole', only: ['edit']
  @before 'generateRequirementTypes', only: ['edit']

  index: (done) ->
    @req.user.getActiveRoles (err, @activeRoles) =>
      @activeRoleIds = (role.id for role in @activeRoles)
      return done err if err
      done()

  applications: (done) ->
    done()

  application: (done) ->
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
