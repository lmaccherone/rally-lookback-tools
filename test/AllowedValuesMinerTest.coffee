{AllowedValuesMiner} = require('../')

# !TODO: Need to write some tests

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

    test.done()
