# credit to lmarkus/hubot-conversation for the original concept
# TODO: queue consquetive receive calls to process messages synchronously
# TODO: save transcript to brain (here or in scene)

_ = require 'underscore'
{generate} = require 'randomstring'
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
    @paths = {} # builds as dialogue progresses
    @pathKey = null # pointer for current path
    @branches = [] # options within current path
    @ended = false # state of dialogue completion
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
  keygen: (source='') -> if source isnt '' then slug source else generate 12

  # add a dialogue path - a prompt with one or more branches to follow
  # @param prompt, string to send to user presenting the options
  # @param branches, 2D array of arguments to create branches
  # @param key, (optional) string reference for querying results of path
  path: (prompt, branches, key) ->

    # generate key if not provided and make sure its unique
    key ?= @keygen prompt
    console.log key, _.keys @paths
    if key in _.keys @paths
      @logger.error "Path key '#{ key }' already exists, cannot overwrite"
      return false

    # setup new path object and dialogue state
    @clearBranches()
    @pathKey = key
    @paths[key] =
      prompt: prompt
      status: _.map branches, (args) => @branch args...
      transcript: []

    # kick-off dialogue exchange
    @send prompt if prompt isnt ''

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
    @branches.push
      regex: regex,
      handler: handler
    return true # for .path to record success

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
        # match found, clear this step
        @record 'match', res.message.user, line, match, branch.regex
        @clearBranches()
        @clearTimeout()

        res.match = match # override the original match from hubot listener
        branch.handler res # may add additional branches / restarting timeout
        return true # don't process further matches

    # record and report if nothing matched
    @record 'mismatch', res.message.user, line if not match
    @end() if @branches.length is 0 # end if nothing left to do

  # Send response using original response object
  # Address the audience appropriately (i.e. @user reply or send to channel)
  send: (line) ->
    if @config.reply then @res.reply line else @res.send line
    @record 'send', 'bot', line

  # record and report sends, matches or mismatches
  # adds interactions to transcript if currently executing a named path
  record: (type, user, content, match, regex) ->
    @paths[@pathKey].transcript.push [ type, user, content ] if @pathKey?
    switch type
      when 'match'
        @logger.debug "Received \"#{ content }\" matched #{ inspect regex }"
        @emit 'match', user, content, match, regex
      when 'mismatch'
        @logger.debug "Received \"#{ content }\" matched nothing"
        @emit 'mismatch', user, content
      when 'send'
        @logger.debug "Sent \"#{ content }\""

  # shut it down - emit status for scene to disengage participants
  end: ->
    return false if @ended
    complete = @branches.length is 0
    @logger.debug "Dialog ended #{ if not complete then 'in' }complete"
    @clearTimeout() if @countdown?
    @emit 'end', complete
    @ended = true

module.exports = Dialogue
