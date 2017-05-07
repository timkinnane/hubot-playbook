# Description
#   Diagnostics interactions provide a baseline measure before doing anything
#   more complicated. They work on Hubot without any modules of Playbook.
#
# Configuration:
#   N/A
#
# Commands:
#   hubot which version - Responds with the NPM version of this package
#   is hubot listening? - Responds letting you know its listening
#
# Notes:
#   These commands provide basic diagnostics about the hubot using them
#   Hear anyone asking...
#   - Is hubot listening?
#   - Are any hubots listening?
#   - Is there a bot listening?
#   - Hubot are you listening?
#   ...also works with bot name and alias
#
# Author:
#   Tim Kinnane

module.exports = (robot) ->

  robot.respond /which version/i, (res) ->
    res.reply "I'm currently running version #{ robot.parseVersion() }"

  hearTest = ".*\\b((hu)?bot(s)?|#{robot.name}"
  hearTest+= "|#{robot.alias}" if robot.alias?
  hearTest+= ").*\\b(listening).*"
  hearTest = new RegExp hearTest, 'i'
  robot.hear hearTest, (res) ->
    res.send "Yes, I'm listening."
