{expect, sinon, stub, catchErrors} = require '../test_helper'

describe 'RoleUser', ->
  before ->
    @user = new @_models.User
      id: 9324
      email:"example@example.com"
      username: "example"
      password: "s3krit!!"

  before ->
    @role = new @_models.Role
      id: 2345
      name: 'Arbitrary'
      meta:
        requirements: [
          {
            type: 'text'
            text: "Arbitrary"
          }
        ]

  describe 'requirements', ->
    it 'passes text', (done) ->
      roleUser = new @_models.RoleUser
      roleUser._checkRequirement {type: 'text', text: 'Arbitrary'}, (err) ->
        expect(err).to.not.exist
        done()

    it 'passes role if user has role', (done) ->
      stub @user, "hasActiveRole", catchErrors done, (_role, callback) =>
        expect(_role).to.equal @role.id
        callback true

      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser._checkRequirement {type: 'role', roleId: @role.id}, catchErrors done, (err) =>
        @user.hasActiveRole.restore()
        roleUser.getUser.restore()
        expect(err).to.not.exist
        done()

    it 'fails role if user hasn\'t role', (done) ->
      stub @user, "hasActiveRole", catchErrors done, (_role, callback) =>
        expect(_role).to.equal @role.id
        callback false

      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser._checkRequirement {type: 'role', roleId: @role.id}, catchErrors done, (err) =>
        @user.hasActiveRole.restore()
        roleUser.getUser.restore()
        expect(err).to.exist
        done()
