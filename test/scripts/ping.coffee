# Description:
#   Very basic script for response testing
#
# Dependencies:
#   N/A
#
# Configuration:
#   N/A
#
# Commands:
#   hubot ping - responds with pong
#
# Author:
#   Tim Kinnane
#
module.exports = (robot) ->

  # talk when talked to
  robot.respond /ping/, (res) -> res.reply 'pong'
