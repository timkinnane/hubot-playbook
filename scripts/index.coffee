# Description
#   Just for running Hubot in dev-dependencies with this package, for tests
#
# Configuration:
#   N/A
#
# Commands:
#   N/A
#
# Notes:
#   This file won't be used when Playbook is required as a module.
#
# Author:
#   Tim Kinnane[@4thParty]
Playbook = require '../index.coffee'
module.exports = (robot, scripts) ->  Playbook robot, scripts
