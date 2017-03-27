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
#   timkinnane
#
{inspect} = require 'util'

module.exports = (robot) ->

  # talk when talked to
  robot.respond /ping/, (res) -> res.reply 'pong'

  # don't suffer in silence
  robot.error (err, res) ->
    robot.logger.error inspect err
    res.reply "ROBOT ERROR" if res?

  # events allow tests to listen in
  robot.receiveMiddleware (context, next, done) ->
    robot.emit 'receive', context.response
    next()
  robot.responseMiddleware (context, next, done) ->
    robot.emit 'respond', context.response, context.strings, context.method
    next()
