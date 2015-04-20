fs = require('fs')
path = require('path')
lineReader = require('line-reader')
lumenize = require('lumenize')
{Store, TimeSeriesCalculator, Time} = lumenize

_truncate = (n, decimals) ->
  decade = Math.pow(10, decimals)
  n = Math.floor(n * decade) / decade

randomIndex = (n) ->
  return Math.floor(Math.random() * n)

workItemRootObjectID = 23023583724

snapshotDumpPath = path.join(__dirname, '' + workItemRootObjectID + '-dump.json')
unless fs.existsSync(snapshotDumpPath)
  throw new Error("Missing #{snapshotDumpPath}")

lineCount = 0
totalLines = 3057

config =
  uniqueIDField: 'ObjectID'

store = new Store(config)

outputDumpFilePath = path.join(__dirname, '' + workItemRootObjectID + '-dump.json')
unless fs.existsSync(outputDumpFilePath)
  fs.writeFileSync(outputDumpFilePath, "")

callback = (line, last) ->
  unless lineCount % 1000
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
    console.log("#{lineCount} snapshots")
    filtered = store.filtered((row) ->
      23021657561 in row._TypeHierarchy   # User Stories
    )
    console.log(filtered.length)

    acceptedValues = ['Accepted', 'Released']

    metrics = [
      {as: 'StoryCountBurnUp', f: 'filteredCount', filterField: 'ScheduleState', filterValues: acceptedValues},
      {as: 'StoryUnitBurnUp', field: 'PlanEstimate', f: 'filteredSum', filterField: 'ScheduleState', filterValues: acceptedValues},
      {as: 'StoryUnitScope', field: 'PlanEstimate', f: 'sum'},
      {as: 'StoryCountScope', f: 'count'},
      {as: 'TaskUnitBurnDown', field: 'TaskRemainingTotal', f: 'sum'},
      {as: 'TaskUnitScope', field: 'TaskEstimateTotal', f: 'sum'},
    ]

    summaryMetricsConfig = [
      {field: 'TaskUnitScope', f: 'max'},
      {field: 'TaskUnitBurnDown', f: 'max'},
      {as: 'TaskUnitBurnDown_max_index', f: (seriesData, summaryMetrics) ->
        for row, index in seriesData
          if row.TaskUnitBurnDown is summaryMetrics.TaskUnitBurnDown_max
            return index
      }
    ]

    deriveFieldsAfterSummary = [
      {as: 'Ideal', f: (row, index, summaryMetrics, seriesData) ->
        max = summaryMetrics.TaskUnitScope_max
        increments = seriesData.length - 1
        incrementAmount = max / increments
        return Math.floor(100 * (max - index * incrementAmount)) / 100
      },
      {as: 'Ideal2', f: (row, index, summaryMetrics, seriesData) ->
        if index < summaryMetrics.TaskUnitBurnDown_max_index
          return null
        else
          max = summaryMetrics.TaskUnitBurnDown_max
          increments = seriesData.length - 1 - summaryMetrics.TaskUnitBurnDown_max_index
          incrementAmount = max / increments
          return Math.floor(100 * (max - (index - summaryMetrics.TaskUnitBurnDown_max_index) * incrementAmount)) / 100
      },
      {as: 'Velocity', f: (row, index, summaryMetrics, seriesData) ->
        if index is 0
          return null
        else
          return row.StoryUnitBurnUp - seriesData[index - 1].StoryUnitBurnUp
      }
    ]

    projectionsConfig = {
      limit: 45  # optional, defaults to 300
#      continueWhile: (point) ->  # Optional but recommended
#        return point.StoryUnitScope_projection > point.StoryUnitBurnUp_projection
      minFractionToConsider: 1.0 / 2.0  # optional, defaults to 1/3
      minCountToConsider: 3  # optional, defaults to 15
      series: [
        {field: 'StoryUnitScope', slope: 0},  # 0 slope is a level projection
        {as: 'LinearProjection', field: 'StoryUnitBurnUp', startIndex: 0}
      ]
    }

    config =
#      deriveFieldsOnInput: deriveFieldsOnInput
      metrics: metrics
      summaryMetricsConfig: summaryMetricsConfig
      deriveFieldsAfterSummary: deriveFieldsAfterSummary
      granularity: lumenize.Time.DAY
      tz: 'America/Chicago'
#      holidays: holidays
#      workDays: 'Sunday,Monday,Tuesday,Wednesday,Thursday,Friday' # They work on Sundays
      projectionsConfig: projectionsConfig

    calculator = new TimeSeriesCalculator(config)

    startOnISOString = new Time('2015-01-09').getISOStringInTZ(config.tz)
    upToDateISOString = new Time('2015-02-22').getISOStringInTZ(config.tz)
    calculator.addSnapshots(filtered, startOnISOString, upToDateISOString)

    series = calculator.getResults().seriesData

    velocities = []
    lastIndexForData = 0
    for row, i in series
      if row.Velocity?
        velocities.push(row.Velocity)
      if row.StoryUnitBurnUp?
        lastIndexForData = i

    maxIndex = series.length - 1

    n = velocities.length

    for i in [lastIndexForData..series.length - 1]
      row = series[i]
      row.accumulator = 0

    simulationsRun = 0
    targetNumberOfSimulations = 10000

    while simulationsRun < targetNumberOfSimulations
      currentIndex = lastIndexForData
      currentBurnUp = series[currentIndex].StoryUnitBurnUp
      currentScope = series[currentIndex].StoryUnitScope_projection
      while currentBurnUp < currentScope and currentIndex <= maxIndex
        currentBurnUp += velocities[randomIndex(n)]
        currentIndex++
        currentScope = series[currentIndex]?.StoryUnitScope_projection
      forecastIndex = currentIndex - 1
      series[forecastIndex].accumulator++
      simulationsRun++

    cumulativeProbability = 0
    for i in [lastIndexForData..series.length - 1]
      row = series[i]
      row.probability = row.accumulator / targetNumberOfSimulations
      cumulativeProbability += row.probability
      row.cumulativeProbability = cumulativeProbability



    keys = ['label', 'StoryUnitScope', 'StoryUnitBurnUp', 'Velocity', 'LinearProjection', 'probability', 'cumulativeProbability']
    #    keys = ['label', 'StoryUnitScope', 'StoryCountScope', 'StoryCountBurnUp',
    #            'StoryUnitBurnUp', 'TaskUnitBurnDown', 'TaskUnitScope', 'Ideal', 'Ideal2']

    lumenize.utils.log(lumenize.table.toString(series, keys))





lineReader.eachLine(snapshotDumpPath, callback)
