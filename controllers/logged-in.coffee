Controller = require '../controller'

class LoggedInController extends Controller
  @before 'requireLoggedIn'
  @before 'generateNav'

  requireLoggedIn: ->
    @redirectTo "/login?next=#{encodeURIComponent @req.path}" unless @req.user?
    @loggedInUser = @req.user

  generateNav: (done) ->
    # XXX: Get additional nav items from plugins
    @activeNavigationId ?= "#{@templateParent}-#{@template}"
    @navigation = [
      {
        title: @loggedInUser.fullname
        header: true
        id: 'user'
        items: [
          {
            title: 'Dashbard'
            href: '/dashboard'
            id: 'user-dashboard'
          }
          {
            title: 'Account'
            href: '/account'
            id: 'user-account'
          }
          {
            title: 'Subscription'
            href: '/subscription'
            id: 'user-subscription'
            className: 'pending warning'
          }
          {
            title: 'Member list'
            href: '/members'
            id: 'members-index'
          }
        ]
      }
      {
        title: 'Trustees'
        header: true
        id: 'trustees'
        items: [
          {
            title: 'Register of Members'
            href: '/admin/register'
            id: 'admin-register'
          }
          {
            title: 'Banking/Money'
            href: '/admin/money'
            id: 'admin-money'
          }
          {
            title: 'Reminders'
            href: '/admin/reminders'
            id: 'admin-reminders'
          }
          {
            title: 'Emails'
            href: '/admin/emails'
            id: 'admin-emails'
          }
        ]
      }
    ]
    for item in @navigation
      if item.id is @activeNavigationId
        item.active = true
        break
    done()

module.exports = LoggedInController
