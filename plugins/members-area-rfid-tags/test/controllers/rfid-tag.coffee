{catchErrors, expect, reqres, stub, protect, Plugin} = require "#{process.cwd()}/test/test_helper"
protect()
RfidTagsController = require '../../controllers/rfid-tags'

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

  it 'accepts updates', (done) ->
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
          "abcdefg": {
            "assigned_user": "00003",
            "count": 7,
            "scans": [
              {
                "date": 1111111111,
                "location": "door"
              },
              {
                "date": 1222222222,
                "location": "lathe"
              }
            ]
          },
          "01234567": {
            "assigned_user": "00003",
            "count": 8,
            "scans": [
              {
                "date": 1333333333,
                "location": "door"
              }
            ]
          },
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

      res.json = (data) ->
        expect(data).to.be.a 'object'
        expect(data.tags).to.be.a 'object'
        expect(data.users).to.be.a 'object'
        return done()
      RfidTagsController.handle params, req, res

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
