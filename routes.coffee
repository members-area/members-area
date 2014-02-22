module.exports = ({get, post, all}) ->
  get '/', 'static#home'
  all '/login', 'session#login'
  all '/register', 'registration#register'
  all '/dashboard', 'user#dashboard'
