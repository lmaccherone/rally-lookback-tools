{AllowedValuesMiner} = require('../')
fs = require('fs')
path = require('path')
lineReader = require('line-reader')

user = "username"
password = "password"

typesArray = [
  '23021657435',
  '23021657561',
  '23021657268',
  '23021658529',
  '23021656009',
  '23021655943',
  '23021657410'
]

miner = new AllowedValuesMiner(user, password)
miner.fetchAll(typesArray, () ->
  console.log('Done fetching Type Definitions.')
  console.log(miner.typeDefinitions[23021657561].Attributes.Blocker)
  savedStateFilePath = path.join(__dirname, 'type-definitions.json')
  savedState = JSON.stringify(miner.typeDefinitions)
  fs.writeFileSync(savedStateFilePath, savedState, 'utf8')
)
