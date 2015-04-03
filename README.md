[![build status](https://secure.travis-ci.org/lmaccherone/rally-lookback-tools.png)](http://travis-ci.org/lmaccherone/rally-lookback-tools)
# rally-lookback-tools #

Copyright (c) 2015, Lawrence S. Maccherone, Jr.

_A node.js and browser-based toolkit for working with Rally's Lookback API._

## Credits ##

Author: [Larry Maccherone](http://maccherone.com)

## Usage ##

The following example usage will repeatedly fetch pages from the Lookback API and stream them to a file. It will also
save the state of the miner after each page fetch. This way, you can restart a mining operation right where it left
off if you decide to pause it or it crashes for some reason, but more typically, it will keep updating the dump
file as new snapshots are added to the Lookback API. Just run the code below periodically to keep your mined dump
up to date.

Note, there are intentional overlaps between pages (see Miner.fetchPage() for explanation) so you will need to deal with
that when consuming the dump file.

    {Miner} = require('rally-lookback-tools')
    fs = require('fs')
    path = require('path')

    JSONrows = (results) ->
      out = ""
      for row in results
        out += JSON.stringify(row) + "\n"
      return out

    config =
      rootProjectOID: 1234
      workspaceOID: 5678
      hydrate: ['Project', 'Iteration', 'Release']

    user = "your_username"
    password = "your_password"

    savedStateFilePath = path.join(__dirname, 'config.json')
    if fs.existsSync(savedStateFilePath)
      savedState = fs.readFileSync(savedStateFilePath, 'utf8')
      miner = Miner.newFromSavedState(user, password, savedState)
    else
      miner = new Miner(user, password, config)
      savedState = JSON.stringify(miner.getStateForSaving())
      fs.writeFileSync(savedStateFilePath, savedState, 'utf8')

    snapshotDumpPath = path.join(__dirname, 'dump.json')
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

    miner.fetchPage(callback)

## Installation ##

`npm install rally-lookback-tools`

## Changelog ##

* 0.1.0 - 2015-02-12 - Original version (not pushed to npm)


