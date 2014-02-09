module.exports = ({get, post, all}) ->
  get '/', 'static#home'
  all '/register', 'registration#register'
