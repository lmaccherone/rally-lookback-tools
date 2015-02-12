superagent = require('superagent')

class Miner
  ###
  @class Miner

  Mine everything in the LBAPI and keep updating it.
  ###
  @propertyDefaults =
    lastValidFrom: '0001-01-01T00:00:00.000Z'
    baseUri: 'https://rally1.rallydev.com/analytics/v2.0/service/rally'
    hydrate: null
    pagesize: 100
    unauthorizedProjects: []
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
    uri += '&removeUnauthorizedSnapshots=true'

    return uri

  fetchPage: (callback) ->
    superagent
      .get(@getUri())
      .auth(@user, @password)
      .end(callback);

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



processRallyConnection = (connectionConfig) ->

  try

    while true
      uriOptions = {baseUri, hydrateFields, workspaceOID, rootProjectOID, start, pagesize, lastValidFrom, unauthorizedProjects}
      uri = getUri(uriOptions)
      response = syncRequest.get(uri, options)
      newUnauthorizedProjects = response.data.UnauthorizedProjects
      if newUnauthorizedProjects?.length > 0
        unauthorizedProjects = unauthorizedProjects.concat(newUnauthorizedProjects)
        console.error('Adding to unauthorizedProjects and retrying\n', unauthorizedProjects)
        continue
      results = response.data.Results
      requestCount++
      lastTotalResultCount = response.data.TotalResultCount
      pagesize = response.data.PageSize
      shouldGet = Math.min(lastTotalResultCount, pagesize)

      newLastValidFrom = results[results.length - 1]._ValidFrom
      if newLastValidFrom == lastValidFrom
        console.error("LastValidFrom is the same as prior lastValidFrom. Incrementing lastValidFrom by 1 millisecond to prevent deadlock. There is a risk of skipping snapshots.")
        lastValidFrom = new Date(new Date(lastValidFrom).getTime() + 1).toISOString()
      else
        lastValidFrom = newLastValidFrom

      resultsString = JSONrows(results)
      fs.appendFileSync('../../../../../../boa.json', resultsString)

      snapshotsRemaining = lastTotalResultCount - results.length
      snapshotsSoFar = requestCount * pagesize
      millisecondsElapsed = new Date() - startDate
      millisecondsPerSnapshot = millisecondsElapsed / snapshotsSoFar
      timeRemaining = snapshotsRemaining * millisecondsPerSnapshot
      portionComplete = snapshotsSoFar / (snapshotsSoFar + snapshotsRemaining)
      percentComplete = truncate(100 * portionComplete, 2)
      console.log("#{percentComplete}%  Time remaining: #{truncate(timeRemaining / 1000 / 60, 0)} minutes")

      if lastTotalResultCount < pagesize
        break

    return