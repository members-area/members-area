module.exports = -> (req, res, next) ->
  pad = res.locals.pad = (n, l=2, p="0") ->
    n = ""+n
    if n.length < l
      n = new Array(l - n.length + 1).join(p) + n
    return n
  formatDate = res.locals.formatDate = (d) ->
    return (d.getFullYear())+"-"+pad(d.getMonth()+1)+"-"+pad(d.getDate())
  next()
