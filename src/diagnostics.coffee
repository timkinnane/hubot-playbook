# Description
#   A hubot script that does the things
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
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
#   Tim Kinnane[@4thParty]

module.exports = (robot) ->

  robot.respond /which version/i, (res) ->
    pjson = require '../package.json'
    res.reply "I'm currently running version #{ pjson.version }"

  hearTest = ".*\\b((hu)?bot(s)?|#{robot.name}"
  hearTest+= "|#{robot.alias}" if robot.alias?
  hearTest+= ").*\\b(listening).*"
  robot.hear new RegExp(hearTest,'i'), (res) ->
    res.send "Yes, I'm listening."
