LoggedInController = require 'members-area/app/controllers/logged-in'
async = require 'async'

class SubscriptionController extends LoggedInController
  view: (done) ->
    @req.models.Payment.find()
    .where(user_id: @loggedInUser.id)
    .order("-id")
    .all (err, @payments) =>
      done(err)

module.exports = SubscriptionController
