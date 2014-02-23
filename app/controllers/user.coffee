LoggedInController = require './logged-in'
passport = require '../passport'

module.exports = class UserController extends LoggedInController
  dashboard: ->
