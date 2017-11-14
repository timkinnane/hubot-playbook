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

module.exports = (robot) ->
  require '../../lib'
  .use robot
  .sceneHear /knock/, scope: 'direct', sendReplies: true, (res) ->
    res.dialogue.addPath "Who's there?"
    res.dialogue.addBranch /.*/, (res) ->
      res.dialogue.addPath "#{ res.match[0] } who?"
      res.dialogue.addBranch /.*/, "lol"
