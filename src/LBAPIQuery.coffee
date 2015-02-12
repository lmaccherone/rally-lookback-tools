class LBAPIQuery
  ###
  @class LBAPIQuery
  ###
  constructor: () ->
    unless this instanceof LBAPIQuery  # get an instance without "new"
      return new LBAPIQuery()  # !TODO: Remember to pass in the parameters of the constructor here.


exports.LBAPIQuery = LBAPIQuery