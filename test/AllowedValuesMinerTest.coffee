{AllowedValuesMiner} = require('../')

config =
  rootProjectOID: 1234
  workspaceOID: 5678

exports.AllowedValuesMinerTest =

  testInstantiate: (test) ->
    miner = new AllowedValuesMiner('user', 'password', config)


    test.done()

  testGetUri: (test) ->
    config =
      rootProjectOID: 1234
      workspaceOID: 5678

    miner = new AllowedValuesMiner('user', 'password', config)
    test.equal(miner._getUri(), 'https://rally1.rallydev.com/analytics/v2.0/service/rally/workspace/5678/artifact/snapshot/query.js?find={"_ProjectHierarchy":1234,"_ValidFrom":{"$gte":"0001-01-01T00:00:00.000Z"}}&fields=true&sort={_ValidFrom:1}&pagesize=100000&start=0&removeUnauthorizedSnapshots=true')

    test.done()
