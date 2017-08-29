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
#   scope: room
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
  pb = require '../../lib/index.js'
  .use robot

  # knock to enter
  enterScene = pb.sceneHear /knock/,
    scope: 'direct',
    sendReplies: true
  , (res) -> res.dialogue.send "You may enter!"

  # scene resposne adds a whitelist director to another scene
  whitelistScene = pb.sceneHear /allow (.*)/, (res) ->
    room = res.match[1]
    roomDirector = pb.director
      deniedReply: "Sorry, #{room} users only."
      scope: 'room'
    roomDirector.add room
    roomDirector.directScene enterScene

  # scene resposne adds a blacklist director to another scene
  blacklistScene = pb.sceneHear /deny (.*)/, (res) ->
    room = res.match[1]
    roomDirector = pb.director
      deniedReply: "Sorry, no #{room} users."
      type: 'blacklist'
      scope: 'room'
    roomDirector.add room
    roomDirector.directScene enterScene

  # only 'director' user can configure whitelist/blacklist
  director = pb.director deniedReply: null
  director.add 'director'
  director.directScene whitelistScene
  director.directScene blacklistScene
