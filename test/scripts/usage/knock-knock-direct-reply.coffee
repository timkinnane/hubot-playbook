# Description:
#   Tell Hubot a knock knock joke - it is guaranteed to laugh
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
Playbook = require '../../../index.coffee'

module.exports = (robot) ->
  @pb = new Playbook robot
  @pb.sceneHear /knock/, 'direct', sendReplies: true, ->
    @send "Who's there?"
    @branch /.*/, (res) =>
      @send "#{ res.match[0] } who?"
      @branch /.*/, "lol"
