LoggedInController = require './logged-in'
passport = require '../lib/passport'

module.exports = class UserController extends LoggedInController
  dashboard: ->
  account: ->
