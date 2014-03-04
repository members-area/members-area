LoggedInController = require './logged-in'

module.exports = class RoleController extends LoggedInController
  @before 'loadRoles', only: ['index', 'admin']

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
    return done new @req.HTTPError 403, "Permission denied" unless @req.user.can('admin_roles')
    done()

  loadRoles: (done) ->
    @req.models.Role.find (err, @roles) =>
      done(err)
