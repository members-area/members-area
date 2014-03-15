{expect, sinon, stub, catchErrors} = require '../test_helper'

describe 'Role', ->
  before (done) ->
    @role = new @_models.Role
      name: 'RandomRoleName'
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

  describe 'canApply', ->
    it 'returns true for text/approval', (done) ->
      @role.canApply @trustee, (canApply) =>
        expect(canApply).to.eql true
        done()

    it 'returns false for role you don\'t have', (done) ->
      @role.meta.requirements.push
        type: 'role'
        roleId: 99999999999
      @role.canApply @trustee, (canApply) =>
        expect(canApply).to.eql false
        done()

    it 'returns true for roles you do have', (done) ->
      @role.meta.requirements[@role.meta.requirements.length - 1].roleId = 1
      @role.canApply @trustee, (canApply) =>
        expect(canApply).to.eql true
        done()
