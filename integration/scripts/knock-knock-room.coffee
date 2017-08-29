# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
#   Uses object oreiented path declarations, simpler to read and pass callbacks
#
# Dependencies:
#   hubot-playbook
#
# Configuration:
#   Playbook room scene responds to the whole room
#
# Commands:
#   knock - it will say "Who's there", then "{your answer} who?", then "lol"
#
# Author:
#   Tim Kinnane
#
playbook = require '../../lib/index.js'

module.exports = (robot) ->

  steps =
    who1: (res) -> res.dialogue.addPath "Who's there?", [
      [ /.*/, steps.who2 ]
    ]
    who2: (res) -> res.dialogue.addPath "#{ res.match[0] } who?", [
      [ /.*/, steps.lol ]
    ]
    lol: (res) -> res.dialogue.send "lol"

  playbook.use robot
  .sceneHear /knock/, scope: 'room', steps.who1
