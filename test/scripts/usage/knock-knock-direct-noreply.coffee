# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
#   Uses inline declarations, single branch path with prompt (very compact)
#
# Dependencies:
#   hubot-playbook
#
# Configuration:
#   Playbook direct scene responds to a single user and room
#   sendReplies: false by default - Hubot will send to room not reply to user
#
# Commands:
#   knock - it will say "Who's there", then "{your answer} who?", then "lol"
#
# Author:
#   Tim Kinnane
#
Playbook = require '../../../index.coffee'

module.exports = (robot) ->

  new Playbook robot
  .sceneHear /knock/, 'direct', (res, dlg) ->
    dlg.addPath "Who's there?", [ /.*/, (res, dlg) ->
      dlg.addPath "#{ res.match[0] } who?", [ /.*/, "lol" ]
    ]
