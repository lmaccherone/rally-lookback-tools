superagent = require('superagent')

_truncate = (n, decimals) ->
  decade = Math.pow(10, decimals)
  n = Math.floor(n * decade) / decade

class Miner
  ###
  @class Miner

  Mine everything in the Rally Lookback API and keep updating it.

  See front page of this documentation (README.MD) for an example of using this Miner class.
  ###
  ###
  @property morePages This will be false if the last call to fetchPage() got all of the available snapshots.
  ###
  ###
  @property lastValidFrom The _ValidFrom for the last snapshot in the results
  ###
  ###
  @property snapshotsSoFar How many snapshots have been retrieved since the Miner was instantiated
  ###
  ###
  @property minutesRemaining Estimated minutes remaining snapshots are retrieved
  ###
  ###
  @property percentComplete Percent complete as calculated from when this Miner was instantiated.
  ###
  @propertyDefaults =
    lastValidFrom: '0001-01-01T00:00:00.000Z'
    baseUri: 'https://rally1.rallydev.com/analytics/v2.0/service/rally'
    hydrate: null
    unauthorizedProjects: []
    pagesize: 100000  # Start out with something really large and let it get set by the first response
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

  _getUri: () ->
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
    ###
    @method fetchPage
      This is what you'll repeatedly call to fetch a "page" of data from the LBAPI.

      This code was carefully designed so that it can be restarted if interrupted. It can also be rerun periodically
      to keep up with the ever growing list of snapshots in your Lookback API. This is accomplished by triggering
      off of the _ValidFrom field. I assume that for each snapshot made available via the Lookback API, its _ValidFrom
      is greater than or equal to the snapshot before it. When a "page" is fetched the state of the lastValidFrom
      property in the miner is updated to the last _ValidFrom in the sorted results. The next call to the fetchPage() will
      look for snapshots that are greater than or equal to the prior last _ValidFrom. There are a few implications
      of this approach to which you should be aware:

      1. There will be overlaps between pages. At the very least, the last snapshot of one page will be fetched again
         as the first snapshot of the next page. You will need to deal with this before consuming the resulting stream.
         In my case, the place where I am storing these snapshots is idempotent such that sending in a snapshot with
         the exact same values will not duplicate it.
      2. One call to fetchPage() might result in more than one pagesize's worth of snapshots being returned. Why?
         Well, it is possible to have more than 100 (the LBAPI default page size) snapshots in a row with the same
         _ValidFrom. In fact, it's fairly common when Project hierarchies are adjusted. If we didn't take this into
         account, the first and last _ValidFrom's in a given page would match and the page fetching would never advance.
         So, a single one of your calls to fetchPage() might actually result in fetching of more than one actual
         Lookback API page before returning the results back to you.

      Advice

      Limitations:

      1. The Lookback API indicates that a work item is deleted by changing its _ValidTo to the moment that it's deleted.
         Since this miner only senses new snapshots, you'll miss when a work item is deleted or even when it's moved
         out of scope of the miner's rootProject or your permissions. The ideal way to deal with this would be to monitor the event stream
         and trigger an update at that time. I know of no publicly available documentation of such functionality at
         this time (2015-02-14), but maybe Rally will offer this some day. For now, I periodically check for snapshots
         where my copy of the snapshot has "9999-01-01T00:00:00.000Z" as the _ValidTo to see the APIs _ValidTo has changed.
      2. If more projects are added to your permissions, you should rerun the mining operation from the start or patch
         up your copy of the missing permissions. Ideally, you would configure this miner to run as a user with broad
         permissions to read every work item in the system. The miner deals gracefully with missing permissions even
         keeping track of unauthorized projects. You can use the @unauthorizedProjects property to periodically check
         if you've been granted permission, fetch, and patch those snapshots into your copy. However, work items that
         are moved out of the scope of the rootProject config will be missing some history.

    @param {Function} callback
    @return {Object}
      The callback is called an object containing everything that came back from the superagent, plus a few other.

      **response.results** - The parsed/Objectified contents of the Results section of the Lookback API response
      **response.data** - The full response of the last Lookback API call. Note, response.data.Results will only
        contain the last page. You should use response.results.
    ###
    responseProcessor = (response) =>
      data = JSON.parse(response.text)
      @pagesize = data.PageSize
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
          @minutesRemaining = _truncate(snapshotsRemaining * millisecondsPerSnapshot / 1000 / 60, 0)
          portionComplete = @snapshotsSoFar / (@snapshotsSoFar + snapshotsRemaining)
          @percentComplete = _truncate(100 * portionComplete, 2)

          response.data = data
          response.results = @results
          @results = []
          @start = 0
          @callback(response)

    superagent
      .get(@_getUri())
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

