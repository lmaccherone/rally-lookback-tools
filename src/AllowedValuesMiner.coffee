superagent = require('superagent')

# !TODO: Check Predecessors, Successors, Blocker (Blocked Reason?)

_truncate = (n, decimals) ->
  decade = Math.pow(10, decimals)
  n = Math.floor(n * decade) / decade

class AllowedValuesMiner  # !TODO: Add timeout.
  ###
  @class AllowedValuesMiner

  Mine the TypeDefinitions, Attributes, and AllowedValues from Rally's WSAPI and keep updating it.

  Example: TBD

      typeDefinitions: {
        1234: {                       # key = ObjectID of lowest-level type
          ObjectID: '1234',
          Name: 'Release or Theme',
          DisplayName: 'Portfolio Item Release or Theme',
          ElementName: 'ReleaseorTheme',
          TypePath: 'PortfolioItem/ReleaseorTheme',
          IDPrefix: 'R',
          Note: 'This is the highest level portfolio item.',
          Attributes: {               # key = ElementName of Attribute
            WorkProduct: {            # Two kinds of attributes: 1) without AllowedValues
              Name: 'Work Product',
              ElementName: 'WorkProduct',
              Type: 'SchedulableArtifact',
              AttributeType: 'OBJECT',
              RealAttributeType: 'OBJECT'
            },
            State: {                  # 2) with AllowedValues
              Name: 'State',
              ElementName: 'State',
              Type: 'string',
              AttributeType: 'STRING',
              RealAttributeType: 'DROP_DOWN',
              AllowedValues: ['Defined', 'In-Progress', 'Completed', 'Accepted']
            },
            ...
          }
        },
        ...
      }
  ###
  ###
  @property something This is the documentation for some property.
  ###
  @propertyDefaults =
    baseUri: 'https://rally1.rallydev.com/slm/webservice/v2.0/'
    typeDefinitions: {}
    allowedValues: {}

  constructor: (@user, @password, config = {}) ->
    unless this instanceof AllowedValuesMiner  # get an instance without "new"
      return new AllowedValuesMiner(user, password, config)

    unless @user?
      throw new Error('user is required when instantiating a new AllowedValuesMiner')
    unless @password?
      throw new Error('password is required when instantiating a new AllowedValuesMiner')

    for variable, defaultValue of AllowedValuesMiner.propertyDefaults
      this[variable] = config[variable] ? defaultValue

    @definitionsLeft = null
    @currentID = null
    @pendingIDs = []
    @pendingAllowedValues = 0
    @fullTypeDefinitions = {}

  fetchAll: (typeOIDsList, @callback) ->  # !TODO: Add timeout
    @definitionsLeft = typeOIDsList.length
    for type in typeOIDsList  # We can make all of these requests in parallel because the response is self-identified
      uri = @baseUri + 'TypeDefinition/' + type
      superagent
        .get(uri)
        .auth(@user, @password)
        .set('Accept', 'application/json')
        .end(@gotTypeDefinition)

  gotTypeDefinition: (response) =>
    data = JSON.parse(response.text)
    td = data.TypeDefinition
    @fullTypeDefinitions[td.ObjectID] = td
    @definitionsLeft--
    @pendingIDs.push(td.ObjectID)
    if @definitionsLeft is 0
      @getPendingAttributeLists()

  getPendingAttributeLists: () ->  # We have to make these requests one at a time and wait for the response before sending the next request because it's unclear which response goes with which request
    if @pendingIDs.length is 0
      @getAllowedValues()
    else
      @currentID = @pendingIDs.pop()
      uri = @baseUri + 'TypeDefinition/' + @currentID + "/Attributes?pagesize=200"  # !TODO: Refactor this like Allowed Values calling all at once in parallel counting on response.request holding this uri
      superagent
        .get(uri)
        .auth(@user, @password)
        .set('Accept', 'application/json')
        .end(@gotAttributeList)

  gotAttributeList: (response) =>
    data = JSON.parse(response.text).QueryResult
    if data.Results.length < data.TotalResultCount
      throw new Error('Currently this TypeAttributeMiner only works when there is less than 200 attributes.')
    @fullTypeDefinitions[@currentID].Attributes = data.Results
    @getPendingAttributeLists()

  getAllowedValues: () ->
    for objectID, td of @fullTypeDefinitions
      for a in td.Attributes
        if a.AllowedValues.Count > 0
          if a.RealAttributeType in ['DROP_DOWN', 'RATING'] or a.Name in ['State', 'Schedule State', 'Preliminary Estimate']
            uri = a.AllowedValues._ref + '?pagesize=200'
            unless @allowedValues[uri]?
              @allowedValues[uri] = []
            @allowedValues[uri].push(a)
            @pendingAllowedValues++
            superagent
              .get(uri)
              .auth(@user, @password)
              .set('Accept', 'application/json')
              .end(@gotAllowedValues)
          else
            unless a.Name in ['Project', 'Iteration', 'Release', 'Owner', 'Submitted By', 'Feature']
              console.error("Field #{a.ObjectID}:#{a.Name} of #{td.ObjectID}:#{td.Name} has AllowedValues.Count > 0 but is not understood.", a.RealAttributeType)

  gotAllowedValues: (response) =>
    @pendingAllowedValues--
    uri = response.request.url
    if @allowedValues[uri]?
      data = JSON.parse(response.text).QueryResult
      results = data.Results
      if results?
        if results.length < data.TotalResultCount
          throw new Error('Currently this miner of Allowed Values only works when there is less than 200 values.')
        for a in @allowedValues[uri]
          a.AllowedValues = results
      else
        throw new Error("No Results for: #{uri}")
    else
      throw new Error("Response without a matching request: #{uri}")
    if @pendingAllowedValues is 0
      @buildSimpleTypeDefinitions()
      @callback(@typeDefinitions, @allowedValues)

  buildSimpleTypeDefinitions: () ->
    tdFields = ['ObjectID', 'Name', 'DisplayName', 'ElementName', 'TypePath', 'IDPrefix', 'Note']
    aFields = ['ObjectID', 'Name', 'ElementName', 'Type', 'AttributeType', 'RealAttributeType']
    for oid, td of @fullTypeDefinitions
      newTD = {}
      for field in tdFields
        newTD[field] = td[field]
      newTD.Attributes = {}
      for a in td.Attributes
        newA = {}
        for field in aFields
          newA[field] = a[field]
        if a.AllowedValues instanceof Array
          newA.AllowedValues = []
          for av in a.AllowedValues
            newA.AllowedValues.push(av.StringValue)
        newTD.Attributes[a.ElementName] = newA
      @typeDefinitions[newTD.ObjectID] = newTD

exports.AllowedValuesMiner = AllowedValuesMiner