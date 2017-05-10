# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
#   Uses inline path declarations, with branches separate (is a little cleaner)
#
# Dependencies:
#   hubot-playbook
#
# Configuration:
#   Playbook direct scene responds to a single user and room
#   sendReplies: ture (false by default) - Hubot will reply to the user
#
# Commands:
#   knock - it will say "Who's there", then "{your answer} who?", then "lol"
#
# Author:
#   Tim Kinnane
#
Playbook = require '../../lib'

module.exports = (robot) ->

  new Playbook robot
  .sceneHear /knock/, 'direct', sendReplies: true, (res, dlg) ->
    dlg.addPath "Who's there?"
    dlg.addBranch /.*/, (res) ->
      dlg.addPath "#{ res.match[0] } who?"
      dlg.addBranch /.*/, "lol"
