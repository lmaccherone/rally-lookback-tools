{LookbackMiner} = require('../')
fs = require('fs')
path = require('path')

JSONrows = (results) ->
  out = ""
  for row in results
    out += JSON.stringify(row) + "\n"
  return out

config =
  rootProjectOID: 23022492300
  workspaceOID: 23022488930
  hydrate: ['Project', 'Iteration', 'Release']
#  lastValidFrom: '2014-10-14T17:55:31.060Z'  # two before
#  lastValidFrom: '2014-10-14T17:58:02.975Z'  # right before

user = "username"
password = "password"

try
  auth = require('auth.json')
  user = auth.user or user
  password = auth.password or password
  config.rootProjectOID = auth.rootProjectOID or config.rootProjectOID
  config.workspaceOID = auth.workspaceOID or config.workspaceOID

savedStateFilePath = path.join(__dirname, 'miner-config.json')
try
  savedState = fs.readFileSync(savedStateFilePath, 'utf8')
  miner = LookbackMiner.newFromSavedState(user, password, savedState)
catch
  miner = new LookbackMiner(user, password, config)
  savedState = JSON.stringify(miner.getStateForSaving())
  fs.writeFileSync(savedStateFilePath, savedState, 'utf8')

snapshotDumpPath = path.join(__dirname, 'miner-dump.json')
unless fs.existsSync(snapshotDumpPath)
  fs.writeFileSync(snapshotDumpPath, "")

callback = (response) ->
  resultsString = JSONrows(response.results)
  fs.appendFileSync(snapshotDumpPath, resultsString)
  savedState = JSON.stringify(miner.getStateForSaving())
  fs.writeFileSync(savedStateFilePath, savedState, 'utf8')
  console.log("Fetched #{response.results.length} snapshots @ #{miner.lastValidFrom}. #{miner.percentComplete}% complete. #{miner.minutesRemaining} minutes remaining.")
  if miner.morePages
    miner.fetchPage(callback)
  else
    console.log('Finished')

console.log('Initializing miner...')
miner.initialize((response)->
  console.log('Starting to fetch pages...')
  miner.fetchPage(callback)
)
