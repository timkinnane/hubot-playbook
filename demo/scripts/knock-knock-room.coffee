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
{playbook} = require '../../lib'

module.exports = (robot) ->

  steps =
    who1: (res, dlg) -> dlg.addPath "Who's there?", [/.*/, steps.who2]
    who2: (res, dlg) -> dlg.addPath "#{ res.match[0] } who?", [/.*/, steps.lol]
    lol: (res, dlg) -> dlg.send "lol"

  playbook.use(robot).sceneHear /knock/, 'room', steps.who1
