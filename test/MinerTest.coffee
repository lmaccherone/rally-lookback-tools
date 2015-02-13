{Miner} = require('../')

config =
  rootProjectOID: 1234
  workspaceOID: 5678

exports.MinerTest =

  testInstantiate: (test) ->
    miner = new Miner('user', 'password', config)
    test.equal(miner.lastValidFrom, '0001-01-01T00:00:00.000Z')

    config.lastValidFrom = 'junk'
    miner2 = new Miner('user', 'password', config)
    test.equal(miner2.lastValidFrom, 'junk')
    savedState = miner2.getStateForSaving()
    test.equal(savedState.lastValidFrom, 'junk')
    miner3 = Miner.newFromSavedState('user', 'password', savedState)
    test.equal(miner3.lastValidFrom, 'junk')
    savedString = JSON.stringify(savedState)
    miner4 = Miner.newFromSavedState('user', 'password', savedString)
    test.equal(miner4.lastValidFrom, 'junk')

    test.done()

  testGetUri: (test) ->
    config =
      rootProjectOID: 1234
      workspaceOID: 5678

    miner = new Miner('user', 'password', config)
    test.equal(miner.getUri(), 'https://rally1.rallydev.com/analytics/v2.0/service/rally/workspace/5678/artifact/snapshot/query.js?find={"_ProjectHierarchy":1234,"_ValidFrom":{"$gte":"0001-01-01T00:00:00.000Z"}}&fields=true&sort={_ValidFrom:1}&pagesize=100&removeUnauthorizedSnapshots=false')

    test.done()
