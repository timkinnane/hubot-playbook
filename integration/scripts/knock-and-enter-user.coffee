# Description:
#   Knock and see if you can enter.
#
# Dependencies:
#   hubot-playbook
#
# Configuration:
#   Playbook directed scene allows only allowed users to enter
#   sendReplies: true - Hubot will reply to the user
#   deniedReply: Hubot's response when denying a user
#   type: whitelist by default
#   scope: user by default
#
# Commands:
#   knock - it will say "Who's there", then "{your answer} who?", then "lol"
#   allow (.*) - setup a director for the scene to whitelist the following name
#   deny (.*) - setup a director for the scene to blacklist the following name
#
# Author:
#   Tim Kinnane
#

module.exports = (robot) ->
  pb = require '../../lib'
  .use robot

  # knock to enter
  enterScene = pb.sceneHear /knock/, sendReplies: true, (res) ->
    res.dialogue.send "You may enter!"

  # scene resposne adds a whitelist director to another scene
  whitelistScene = pb.sceneHear /allow (.*)/, (res) ->
    user = res.match[1]
    # @send "OK, allowing #{user}" #TODO fix after dialogue send fixed
    enterDirector = pb.director deniedReply: "Sorry, #{user}'s only."
    enterDirector.add user
    enterDirector.directScene enterScene

  # scene resposne adds a blacklist director to another scene
  blacklistScene = pb.sceneHear /deny (.*)/, (res) ->
    user = res.match[1]
    # @send "OK, denying #{user}" #TODO fix after dialogue send fixed
    enterDirector = pb.director
      type: 'blacklist',
      deniedReply: "Sorry, no #{user}'s."
    enterDirector.add user
    enterDirector.directScene enterScene

  # only 'director' user can configure whitelist/blacklist
  director = pb.director deniedReply: null
    .add 'director'
  director.directScene whitelistScene
  director.directScene blacklistScene
