fs = require('fs')
path = require('path')
lineReader = require('line-reader')
{Store} = require('lumenize')

argv = require('minimist')(process.argv.slice(2))

arg = argv?['_']?[0]
workItemRootObjectID = Number(arg)
unless workItemRootObjectID?
  console.log('Must provide ObjectID of root work item you want dumped as parameter on command line.')
  process.exit(0)

_truncate = (n, decimals) ->
  decade = Math.pow(10, decimals)
  n = Math.floor(n * decade) / decade

snapshotDumpPath = path.join(__dirname, 'miner-dump.json')
unless fs.existsSync(snapshotDumpPath)
  throw new Error("Missing #{snapshotDumpPath}")

lineCount = 0
totalLines = 330000

config =
  uniqueIDField: 'ObjectID'

store = new Store(config)

outputDumpFilePath = path.join(__dirname, '' + workItemRootObjectID + '-dump.json')
unless fs.existsSync(outputDumpFilePath)
  fs.writeFileSync(outputDumpFilePath, "")

callback = (line, last) ->
  unless lineCount % 10000
    console.log(lineCount, "#{_truncate(100 * lineCount / totalLines, 1)}%")
  lineCount++
  json = JSON.parse(line)
  try
    store.addSnapshots([json])
  catch
    console.log("lastSnapshot\n", store.byUniqueID[json.ObjectID].lastSnapshot)
    console.log("\n\ncurrent snapshot\n",json)
    process.exit(1)

  if last
    filtered = store.filtered((row) ->
      workItemRootObjectID in row._ItemHierarchy
    )
    console.log(filtered.length)
    for row in filtered
      rowString = JSON.stringify(row) + '\n'
      fs.appendFileSync(outputDumpFilePath, rowString)

    console.log('Done writing')
    process.exit(0)


lineReader.eachLine(snapshotDumpPath, callback)
