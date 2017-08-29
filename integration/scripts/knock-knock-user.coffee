# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
#   Uses inline path declarations, this syntax can be a little hard to read
#
# Dependencies:
#   hubot-playbook
#
# Configuration:
#   Playbook user scene responds to each user individually
#
# Commands:
#   knock - it will say "Who's there", then "{your answer} who?", then "lol"
#
# Author:
#   Tim Kinnane
#
playbook = require '../../lib/index.js'

module.exports = (robot) ->

  playbook.use robot
  .sceneHear /knock/, scope: 'user', (res) ->
    res.dialogue.addPath "Who's there?", [
      /.*/, (res) ->
        res.dialogue.addPath "#{ res.match[0] } who?", [
          /.*/, "lol"
        ]
    ]
