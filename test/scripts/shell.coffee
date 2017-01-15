# Description:
#   Testing hubot in the shell with Playbook
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

{Robot} = require 'hubot'
robot = new Robot 'hubot/src/adapters', 'shell'
robot.name = 'hublet'

module.exports = ->

  # talk when talked to
  robot.respond /ping/, (res) -> res.reply 'pong'
