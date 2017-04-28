# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
#   Uses modular path declarations, maybe simpler to read
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
Playbook = require '../../../index.coffee'

module.exports = (robot) ->

  lolAtJoke = (res, dlg) -> dlg.send "lol"
  youAreWho = (res, dlg) -> dlg.addPath "#{ res.match[0] } who?", [ /.*/, lolAtJoke ]
  whoKnocks = (res, dlg) -> dlg.addPath "Who's there?", [ /.*/, youAreWho ]

  new Playbook robot
  .sceneHear /knock/, 'room', whoKnocks
