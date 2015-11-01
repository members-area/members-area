{catchErrors, expect, reqres, stub, protect, Plugin} = require "#{process.cwd()}/test/test_helper"
protect()
RfidTagsController = require '../../controllers/rfid-tags'
async = require 'async'

API_SECRET = 'TESTING_SECRET'

describe 'RfidTagsController', ->
  before ->
    @oldSetting = Plugin.plugins['members-area-rfid-tags']
    Plugin.plugins['members-area-rfid-tags'].setting =
      meta:
        settings:
          apiSecret: API_SECRET

  after ->
    Plugin.plugins['members-area-rfid-tags'] = @oldSetting

  it 'allows fetching the latest details', (done) ->
    models = @_models
    reqres (req, res) ->
      req.method = 'GET'
      req.cookies ?= {}
      req.cookies.SECRET = API_SECRET
      params =
        plugin: 'members-area-rfid-tags'
        controller: 'rfid_tags'
        action: 'list'
      res.json = (data) ->
        expect(data).to.be.a 'object'
        expect(data.tags).to.be.a 'object'
        expect(data.users).to.be.a 'object'
        return done()
      RfidTagsController.handle params, req, res, done

  it 'rejects fetch with invalid secret', (done) ->
    reqres (req, res) ->
      req.method = 'GET'
      req.cookies ?= {}
      req.cookies.SECRET = "WRONG"
      params =
        plugin: 'members-area-rfid-tags'
        controller: 'rfid_tags'
        action: 'list'
      res.json = (status, data) ->
        expect(status).to.be.within 400, 599
        return done()
      RfidTagsController.handle params, req, res

  it 'accepts new tokens', (done) ->
    models = @_models
    reqres (req, res) ->
      req.method = 'PUT'
      req.cookies ?= {}
      req.cookies.SECRET = API_SECRET
      params =
        plugin: 'members-area-rfid-tags'
        controller: 'rfid_tags'
        action: 'list'
      req.body = {
        "tags": {
          "newnew12": {
            "assigned_user": null,
            "count": 1,
            "sector_a_key_a": "a2V5IGEA",
            "sector_a_key_b": "a2V5IGIA",
            "sector_a_secret": "hoteEaISPm56KrcIX67fMWRWEm3GmZU=",
            "sector_a_sector": 1,
            "sector_b_key_a": "a2V5IGEA",
            "sector_b_key_b": "a2V5IGIA",
            "sector_b_secret": "fp6C+KijosMbvxMF9vo3cNS2c98oSGY=",
            "sector_b_sector": 2
          }
        }
      }

      res.json = (status, data) ->
        if !data
          data = status
          status = 200
        expect(status).to.eql 200
        expect(data).to.be.a 'object'
        expect(data.tags).to.be.a 'object'
        expect(data.tags.newnew12).to.be.a 'object'
        expect(data.tags.newnew12.assigned_user).to.be.null
        expect(data.tags.newnew12.count).to.eql 1
        expect(data.tags.newnew12.sector_b_key_b).to.eql "a2V5IGIA"
        expect(data.users).to.be.a 'object'
        return done()
      RfidTagsController.handle params, req, res

  describe 'updates', ->
    before (done) ->
      models = @_models
      async.series
        createUser: (done) =>
          user = new models.User
            username: "rfiduser"
            fullname: "RFID user"
            email: "rfiduser@example.com"
            meta: {}
          user.password = "rfiduser"
          user.save (err, @user) =>
            console.dir err
            return done err if err
            return done()
        createTag: (done) =>
          tag = new models.Rfidtag
            uid: "abcdefgh"
            user_id: @user.id
            count: 1
            secrets: {
              "sector_a_key_a": "a2V5IGEA",
              "sector_a_key_b": "a2V5IGIA",
              "sector_a_secret": "hoteEaISPm56KrcIX67fMWRWEm3GmZU=",
              "sector_a_sector": 1,
              "sector_b_key_a": "a2V5IGEA",
              "sector_b_key_b": "a2V5IGIA",
              "sector_b_secret": "fp6C+KijosMbvxMF9vo3cNS2c98oSGY=",
              "sector_b_sector": 2
            }
            meta: {}
          tag.save (err, @tag) =>
            console.dir err
            return done err if err
            return done()
      , done

    it 'are accepted', (done) ->
      models = @_models
      reqres (req, res) =>
        req.method = 'PUT'
        req.cookies ?= {}
        req.cookies.SECRET = API_SECRET
        params =
          plugin: 'members-area-rfid-tags'
          controller: 'rfid_tags'
          action: 'list'
        paddedUserId = "00000000#{@user.id}".substr(-6)
        req.body = {
          "tags": {
            "#{@tag.uid}": {
              "assigned_user": "#{paddedUserId}",
              "count": 7,
              "scans": [
                {
                  "date": 1411111111,
                  "location": "door"
                },
                {
                  "date": 1422222222,
                  "location": "lathe"
                }
              ]
            }
          }
        }

        res.json = (status, data) =>
          if !data
            data = status
            status = 200
          expect(status).to.eql 200
          expect(data).to.be.a 'object'
          expect(data.tags).to.be.a 'object'
          expect(data.tags[@tag.uid]).to.be.a 'object'
          expect(data.tags[@tag.uid].assigned_user).to.eql paddedUserId
          expect(data.tags[@tag.uid].count).to.eql 7
          expect(data.users).to.be.a 'object'
          return done()
        RfidTagsController.handle params, req, res, done


  it 'rejects update with invalid secret', (done) ->
    reqres (req, res) ->
      req.method = 'PUT'
      req.cookies ?= {}
      req.cookies.SECRET = "WRONG"
      params =
        plugin: 'members-area-rfid-tags'
        controller: 'rfid_tags'
        action: 'list'
      res.json = (status, data) ->
        expect(status).to.be.within 400, 599
        return done()
      RfidTagsController.handle params, req, res
