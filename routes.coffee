module.exports = ({get, post, all}) ->
  get '/', 'static#home'
  all '/login', 'session#login'
  all '/logout', 'session#logout'
  all '/register', 'registration#register'
  all '/dashboard', 'user#dashboard'
  all '/*', 'static#404'
