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
        out += JSON.stringify(row) + ",\n"
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

* 0.1.0 - 2012-10-29 - Original version

## MIT License ##

Copyright (c) 2015, Lawrence S. Maccherone, Jr.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and 
to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
IN THE SOFTWARE.
