{async, expect, catchErrors, protect} = require './test_helper'
protect()

describe "Model", ->
  describe 'instanceMethods', ->
    it 'exists', ->
      @_models.User.instanceMethods.testMethodOne = -> 42
      instance = new @_models.User {id:1, fullname: "Test User"}
      expect(instance.testMethodOne()).to.eq 42

    it 'binds correctly', ->
      @_models.User.instanceMethods.testMethodTwo = -> @id
      instance = new @_models.User {id: 11, fullname: "Test User"}
      expect(instance.testMethodTwo()).to.eq 11

  describe 'instanceProperties', ->
    it 'works', ->
      @_models.User.instanceProperties.name =
        get: -> @fullname
        set: (v) -> @fullname = v
      instance = new @_models.User {id: 22, fullname: "Test User"}
      expect(instance.name).to.eq "Test User"
      instance.fullname = "Bob"
      expect(instance.name).to.eq "Bob"
      instance.name = "Fred"
      expect(instance.name).to.eq "Fred"
      expect(instance.fullname).to.eq "Fred"
