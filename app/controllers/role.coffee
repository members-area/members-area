LoggedInController = require './logged-in'

module.exports = class RoleController extends LoggedInController
  @before 'loadRoles', only: ['index', 'admin', 'edit']
  @before 'ensureAdminRoles', only: ['admin', 'edit']
  @before 'getRole', only: ['edit']

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
      if @data.name?.length
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
      done err
