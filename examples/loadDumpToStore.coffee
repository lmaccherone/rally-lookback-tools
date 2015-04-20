fs = require('fs')
path = require('path')
lineReader = require('line-reader')
{Store} = require('lumenize')

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

callback = (line, last) ->
  unless lineCount % 10000
    console.log(lineCount, "#{_truncate(100 * lineCount / totalLines, 1)}%")
  lineCount++
#  line = line.substring(0, line.length - 1)
  json = JSON.parse(line)
  try
    store.addSnapshots([json])
  catch
    console.log("lastSnapshot\n", store.byUniqueID[json.ObjectID].lastSnapshot)
    console.log("\n\ncurrent snapshot\n",json)
    process.exit(1)
#  if lineCount == 10000
  if last

    filtered = store.filtered((row) ->
      row.ObjectID == 27930887284
    )
    for r in filtered
      console.log(JSON.stringify(r, null, 2))

    process.exit(0)

lineReader.eachLine(snapshotDumpPath, callback)
