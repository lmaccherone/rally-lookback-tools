superagent = require('superagent')

truncate = (n, decimals) ->
  decade = Math.pow(10, decimals)
  n = Math.floor(n * decade) / decade

class Miner
  ###
  @class Miner

  Mine everything in the LBAPI and keep updating it.
  ###
  @propertyDefaults =
    lastValidFrom: '0001-01-01T00:00:00.000Z'
    baseUri: 'https://rally1.rallydev.com/analytics/v2.0/service/rally'
    hydrate: null
    unauthorizedProjects: []
    pagesize: 100
    workspaceOID: -1
    rootProjectOID: -1

  constructor: (@user, @password, config) ->
    unless this instanceof Miner  # get an instance without "new"
      return new Miner(user, password, config)

    unless @user?
      throw new Error('user is required when instantiating a new Miner')
    unless @password?
      throw new Error('password is required when instantiating a new Miner')

    if config.workspaceOID?
      @workspaceOID = config.workspaceOID
    else
      throw new Error('config.workspaceOID is required when instantiating a new Miner')

    if config.rootProjectOID?
      @rootProjectOID = config.rootProjectOID
    else
      throw new Error('config.rootProjectOID is required when instantiating a new Miner')

    for variable, defaultValue of Miner.propertyDefaults
      this[variable] = config[variable] ? defaultValue

    @startDate = new Date()
    @snapshotsSoFar = 0
    @morePages = true
    @results = []
    @start = 0

  getUri: () ->
    find = {"_ProjectHierarchy": @rootProjectOID}
    find._ValidFrom = {"$gte": @lastValidFrom}
    if @unauthorizedProjects.length > 0
      find.Project = {"$nin": @unauthorizedProjects}

    uri = @baseUri
    uri += '/workspace/'
    uri += @workspaceOID
    uri += '/artifact/snapshot/query.js'
    uri += '?find=' + JSON.stringify(find)
    uri += '&fields=true'
    if @hydrate?
      uri += '&hydrate=' + JSON.stringify(@hydrate)
    uri += '&sort={_ValidFrom:1}'
    uri += '&pagesize=' + @pagesize
    uri += '&start=' + @start
    uri += '&removeUnauthorizedSnapshots=true'

    return uri

  fetchPage: (@callback) ->

    responseProcessor = (response) =>
      data = JSON.parse(response.text)
      unless response.ok
        throw new Error(response.text)
      newUnauthorizedProjects = data.UnauthorizedProjects
      if newUnauthorizedProjects?.length > 0
        @unauthorizedProjects = @unauthorizedProjects.concat(newUnauthorizedProjects)
        console.error('Adding to unauthorizedProjects and retrying\n', @unauthorizedProjects)
        @fetchPage(@callback)
      else
        @results = @results.concat(data.Results)
        lastTotalResultCount = data.TotalResultCount
        @morePages = lastTotalResultCount > @pagesize
        newLastValidFrom = @results[@results.length - 1]._ValidFrom
        if @morePages and newLastValidFrom == @lastValidFrom
           @start += @pagesize
           @fetchPage(@callback)
        else
          @lastValidFrom = newLastValidFrom

          @snapshotsSoFar += @results.length
          snapshotsRemaining = lastTotalResultCount - @results.length
          millisecondsElapsed = new Date() - @startDate
          millisecondsPerSnapshot = millisecondsElapsed / @snapshotsSoFar
          @minutesRemaining = truncate(snapshotsRemaining * millisecondsPerSnapshot / 1000 / 60, 0)
          portionComplete = @snapshotsSoFar / (@snapshotsSoFar + snapshotsRemaining)
          @percentComplete = truncate(100 * portionComplete, 2)

          response.data = data
          response.results = @results
          @results = []
          @start = 0
          @callback(response)

    superagent
      .get(@getUri())
      .auth(@user, @password)
      .set('Accept', 'application/json')
      .end(responseProcessor);

  getStateForSaving: () ->
    ###
    @method getStateForSaving
      Enables saving the state of this Miner. The only state it won't save is the user and password.
    @return {Object} Returns an Object representing the state of the Miner. This Object is suitable for saving to
      to an object store. Use the static method `newFromSavedState()` with this Object as the parameter to reconstitute
      the Miner.
    ###
    state = {}
    for variable, value of Miner.propertyDefaults
      state[variable] = this[variable]
    return state

  @newFromSavedState: (user, password, state) ->
    ###
    @method newFromSavedState
      Deserializes a previously saved Miner and returns a new Miner.
    @static
    @param {String/Object} state A String or Object from a previously saved state
    @return {Miner}
    ###
    if typeof state is 'string'
      state = JSON.parse(state)
    return new Miner(user, password, state)

exports.Miner = Miner

