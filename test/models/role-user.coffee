{expect, sinon, stub, catchErrors} = require '../test_helper'

describe 'RoleUser', ->
  before (done) ->
    @user = new @_models.User
      email:"roleusertest@example.com"
      username: "roleusertest"
    @user.password = "s3krit!!"
    @user.save done

  before (done) ->
    @role = new @_models.Role
      name: 'Arbitrary'
      meta:
        requirements: [
          {
            type: 'text'
            text: "Arbitrary"
          }
        ]
    @role.save done

  before (done) ->
    @_models.User.get 1, (err, @trustee) =>
      done(err)

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

    it 'passes approval if user has enough approvals', (done) ->
      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
      roleUser.setMeta
        approvals:
          "1": [1,3,4,7,9]
          "2": [1,3]

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser._checkRequirement {type: 'approval', roleId: 1, count: 5}, catchErrors done, (err) =>
        roleUser.getUser.restore()
        expect(err).to.not.exist
        done()

    it 'fails approval if user has insufficient approvals', (done) ->
      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
        meta:
          approvals:
            "1": [1,3,4,7,9]
            "2": [1,3]

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser._checkRequirement {type: 'approval', roleId: 2, count: 3}, catchErrors done, (err) =>
        roleUser.getUser.restore()
        expect(err).to.exist
        done()

    it 'allows approval', (done) ->
      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
      roleUser.setMeta
        approvals:
          "2": [2,3]

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser.approve @trustee, 2, (err) =>
        expect(err).to.not.exist
        roleUser._checkRequirement {type: 'approval', roleId: 2, count: 3}, catchErrors done, (err) =>
          roleUser.getUser.restore()
          expect(err).to.not.exist
          done()

    it 'forbids double approval', (done) ->
      roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
      roleUser.setMeta
        approvals:
          "2": [1, @trustee.id]

      stub roleUser, "getUser", (callback) =>
        callback null, @user

      roleUser.approve @trustee, 2, (err) =>
        expect(err).to.not.exist
        roleUser._checkRequirement {type: 'approval', roleId: 2, count: 3}, catchErrors done, (err) =>
          roleUser.getUser.restore()
          expect(err).to.exist
          done()

  describe 'getRequirementsWithStatusForUser', ->

    before (done) ->
      @role.setMeta
        requirements: [
          {
            type: 'text'
            text: "Arbitrary"
          }
          {
            type: 'approval'
            roleId: 1
            count: 5
          }
          {
            type: 'approval'
            roleId: 2
            count: 3
          }
        ]
      @role.save done

    before ->
      @roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
        meta:
          approvals:
            "1": [2, 3, 4, 5, 6]
            "2": [2, 3]

    it 'works', (done) ->

      @roleUser.getRequirementsWithStatusForUser @trustee, (err, requirements) ->
        expect(err).to.not.exist
        expect(requirements.length).to.eql 3
        expect(requirements[0].passed).to.eql true
        expect(requirements[1].passed).to.eql true
        expect(requirements[2].passed).to.eql false
        expect(requirements[0].actionable).to.eql false
        expect(requirements[1].actionable).to.eql false
        expect(requirements[2].actionable).to.eql true
        done()

    it 'doesn\'t mark as actionable twice', (done) ->
      @roleUser.meta.approvals["2"][0] = 1

      @roleUser.getRequirementsWithStatusForUser @trustee, (err, requirements) ->
        expect(err).to.not.exist
        expect(requirements.length).to.eql 3
        expect(requirements[0].passed).to.eql true
        expect(requirements[1].passed).to.eql true
        expect(requirements[2].passed).to.eql false
        expect(requirements[0].actionable).to.eql false
        expect(requirements[1].actionable).to.eql false
        expect(requirements[2].actionable).to.eql false
        done()

  describe 'autofetches', ->
    before (done) ->
      @roleUser = new @_models.RoleUser
        user_id:@user.id
        role_id:@role.id
      @roleUser.save done

    it 'role', (done) ->
      @_models.RoleUser.get @roleUser.id, (err, roleUser) =>
        expect(err).to.not.exist
        expect(roleUser.role).to.exist
        expect(roleUser.role.name).to.eq @role.name
        done()
