fs = require 'fs'
_ = require 'lodash'
Base = require './Base'
YAML = require 'yamljs'

###*
 * Define a conversation using an outline object (can load from yaml file)
 * Using Playbook, it maps the bits to scene and paths-branch listeners
 * Will throw if Playbook not attached to robot
 * TODO: requires through docs on possible outline model attributes
 * @param {Robot} robot      - The Hubot instance
 * @param {Object} @bits     - Collection of outline attributes (see docs)
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Outline extends Base
  constructor: (robot, @bits, args...) ->
    super 'outline', robot, args...
    @bits = YAML.load @bits if _.isString @bits and fs.existsSync @bits
    _.forEach _.filter(@bits, 'listen'), (bit) => @setup bit

  setup: (bit) ->
    if bit.scene?
      bit.regex = new RegExp "\\b#{ bit.condition }\\b", 'i'
      @playbook.sceneListen bit.listen # listen type
      , bit.regex # regex
      , bit.scene # scene type
      , bit.options # scene options
      , (res, dlg) => @do bit, res, dlg

  do: (bit, res, dlg) ->
    _.forEach _.castArray(bit.send), (text) -> dlg.send text
    _.forEach _.castArray(bit.callback), (callback) -> callback res, dlg
    if bit.next?
      _.forEach _.castArray(bit.next), (key) =>
        next = @bits[bit.next]
        # dlg.addPath config: catchMessage: bit.catch if bit.catch?
        # dlg.addBranch next.condition, (res, dlg) => @do next, res, dlg
