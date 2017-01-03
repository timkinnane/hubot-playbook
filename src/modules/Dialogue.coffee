# credit to lmarkus/hubot-conversation for the original concept

_ = require 'underscore'
randomstring = require 'randomstring'
slug = require 'slug'
{inspect} = require 'util'
{EventEmitter} = require 'events'

# multiple-choice dialogue interactions
# the timeout will trigger a timeout message if nothing matches in time
# @param res, incoming message initiating dialogue
# @param {object} options key/vals for config, e.g overide timeout default
class Dialogue extends EventEmitter
  constructor: (@res, options={}) ->
    @logger = @res.robot.logger
    @paths = {}
    @currentPath = null
    @branches = []
    @ended = false
    @config = _.defaults options, # use defaults for any missing options
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutLine: process.env.DIALOGUE_TIMEOUT_LINE or
        'Timed out! Please start again.'

  startTimeout: ->
    @countdown = setTimeout () =>
      @emit 'timeout'
      try @onTimeout() catch e then @logger.error "onTimeout: #{ inspect e }"
      delete @countdown
      @end()
    , @config.timeout

  clearTimeout: ->
    clearTimeout @countdown
    delete @countdown

  # default timeout method sends line unless null or method overriden
  # can override by passing in a function, or reassigning the property
  onTimeout: (override) ->
    if override?
      @onTimeout = override
    else
      @send @config.timeoutLine if @config.timeoutLine?

  # helper used by path, generate key from slugifying or random string
  keygen = (source='') -> if source isnt '' then slug source else generate 12

  # add a dialogue path - a prompt with one or more branches to follow
  # @param prompt, string to send to user presenting the options
  # @param branches, 2D array of arguments to create branches
  # @param key, (optional) string reference for querying results of path
  path: (prompt, branches, key) ->

    key ?= keygen prompt # generate key if not provided

    # TODO: Add unit tests for keygen, then...
    # add path key -> object to @paths
    # clear branches
    # set current path to this
    # add branches
    # send prompt if not ''

  # add a dialogue branch (usually through path) with response and/or callback
  # 1: .branch( regex, response ) reply with response on regex match
  # 2: .branch( regex, callback ) trigger callback on regex match
  # 3: .branch( regex, response, callback ) reply and do callback
  # @param regex, expression to match
  # @param {string} response message text (optional)
  # @param {function} handler function when matched (optional)
  branch: (regex, args...) ->
    if @ended
      @logger.error 'attempted to add branch after dialogue completed'
      return false

    # validate arguments
    if not _.isRegExp regex
      @logger.error 'invalid regex given for branch'
      return false
    if typeof args[0] is 'function'
      handler = args[0]
    else if typeof args[0] is 'string'
      handler = (res) =>
        @send args[0]
        args[1] res if typeof args[1] is 'function'
    else
      @logger.error 'wrong args given for branch'
      return false

    # new branch restarts the countdown
    @clearTimeout() if @countdown?
    @startTimeout()
    @branches.push # return new branches length
      regex: regex,
      handler: handler

  clearBranches: -> @branches = []

  # accept an incoming message, match against the registered branches
  # if matched, deliver response, restart timeout and end dialogue
  # @param res, the message object to match against
  receive: (res) ->
    return false if @ended # dialogue is over, don't process

    line = res.message.text
    @logger.debug "Dialogue received #{ line }"
    match = false

    # stop at the first match in the order in which they were added
    @branches.some (branch) =>
      if match = line.match branch.regex
        @logger.debug "`#{ line }` matched #{ inspect branch.regex }"
        @emit 'match', res.message.user, line, match, branch.regex

        # match found, clear this step
        @clearBranches()
        @clearTimeout()

        res.match = match # override the original match from hubot listener
        branch.handler res # may add additional branches / restarting timeout
        return true # don't process further matches

    # report if nothing matched
    @emit 'mismatch', res.message.user, line if not match

    # end if nothing left to do
    @end() if @branches.length is 0

  # Send response using original response object
  # Address the audience appropriately (i.e. @user reply or send to channel)
  send: (line) -> if @config.reply then @res.reply line else @res.send line

  # shut it down - emit status for scene to disengage participants
  end: ->
    return false if @ended
    complete = @branches.length is 0
    @logger.debug "Dialog ended #{ if not complete then 'in' }complete"
    @clearTimeout() if @countdown?
    @emit 'end', complete
    @ended = true

module.exports = Dialogue

# Accept key name for path, or generate unique ID
# Keep history of key and corresponding branch match
# Path contains the message "prompt" that preceed branches
# Each choice answered, resets the current path
# Debounce or queue consquetive receive calls to process messages synchronously
# Save branch matches and mismatches against current path
