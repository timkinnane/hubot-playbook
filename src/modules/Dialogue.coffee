# credit to lmarkus/hubot-conversation for the original concept

_ = require 'underscore'
{inspect} = require 'util'
{EventEmitter} = require 'events'

Helpers = require './Helpers'

# multiple-choice dialogue interactions
# the timeout will trigger a timeout message if nothing matches in time
# @param res, incoming message initiating dialogue
# @param opts, key/vals for config, e.g overide timeout default
class Dialogue extends EventEmitter
  constructor: (@res, opts={}) ->
    @lastRes = _.clone @res # lastRes may be updated, res is initiating response
    @log = @res.robot.logger
    @paths = {} # builds as dialogue progresses
    @pathId = null # pointer for current path
    @branches = [] # branch options within current path
    @ended = false # state of dialogue completion

    @config = _.defaults opts, # use defaults for any missing options
      sendReplies: false # will send without addressing reply to sender
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutLine: process.env.DIALOGUE_TIMEOUT_LINE or
        'Timed out! Please start again.'

  startTimeout: ->
    @countdown = setTimeout () =>
      @emit 'timeout'
      try @onTimeout() catch e then @log.error "onTimeout: #{ inspect e }"
      delete @countdown
      @end()
    , @config.timeout
    return @countdown

  clearTimeout: ->
    clearTimeout @countdown
    delete @countdown
    return

  # default timeout method sends line unless null or method overriden
  # can override by passing in a function, or reassigning the property
  onTimeout: (override) ->
    if override?
      @onTimeout = override
    else
      @send @config.timeoutLine if @config.timeoutLine?
    return

  # add a dialogue path - a prompt with one or more branches to follow
  # @param opts.prompt, (optional) string to send presenting the branches
  # @param opts.branches, 2D array of arguments to create branches
  # @param opts.key, (optional) string reference for querying results of path
  # returns key (either the one given or computed) for future reference
  # Can be called with just the branches array, not required as object param
  path: (opts) ->
    opts = branches: opts if _.isArray opts # move branches array into property

    # generate unique id (using source string if key or prompt given)
    @pathId = Helpers.keygen 'path', opts.key or opts.prompt

    # setup new path object and dialogue state
    @clearBranches()
    @paths[@pathId] =
      prompt: opts.prompt
      status: _.map opts.branches, (args) => @branch args...
      transcript: []

    # kick-off dialogue exchange
    @send opts.prompt if opts.prompt?
    return @pathId # allow path to be queried by key

  # add a dialogue branch (usually through path) with response and/or callback
  # 1: .branch( regex, response ) reply with response on regex match
  # 2: .branch( regex, callback ) trigger callback on regex match
  # 3: .branch( regex, response, callback ) reply and do callback
  # @param regex, expression to match
  # @param {string} response message text (optional)
  # @param {function} handler function when matched (optional)
  branch: (regex, args...) ->
    if @ended
      @log.error 'attempted to add branch after dialogue completed'
      return false

    # validate arguments
    if not _.isRegExp regex
      @log.error 'invalid regex given for branch'
      return false

    # take first arg as response (if string), use remaining as callback if given
    response = args.shift() if _.isString args[0]
    callback = args[0] if _.isFunction args[0]
    if not (response? or callback?)
      @log.error "Wrong args given for branch with regex #{ inspect regex }"
      return false

    # call callback after sending response (if specified) or just call callback
    if response?
      handler = (res) =>
        @send response
        callback res if callback?
    else
      handler = callback

    # new branch restarts the countdown
    @clearTimeout() if @countdown?
    @startTimeout()
    @branches.push
      regex: regex,
      handler: handler
    return true # for .path to record success

  clearBranches: ->
    @branches = []
    return

  # accept an incoming message, match against the registered branches
  # if matched, deliver response, restart timeout and end dialogue
  # @param res, the message object to match against
  receive: (res) ->
    return false if @ended # dialogue is over, don't process

    line = res.message.text
    @log.debug "Dialogue received #{ line }"
    match = false

    # stop at the first match in the order in which they were added
    @branches.some (branch) =>
      if match = line.match branch.regex
        # match found, clear this step
        @record 'match', res.message.user, line, match, branch.regex
        @clearBranches()
        @clearTimeout()
        res.match = match # override the original match from hubot listener
        @lastRes = res # override the original response with current one
        branch.handler res # may add additional branches / restarting timeout
        return true # don't process further matches

    # record and report if nothing matched
    @record 'mismatch', res.message.user, line if not match
    @end() if @branches.length is 0 # end if nothing left to do
    return

  # Send response using original response object
  # Address the participants appropriately (i.e. @user reply or send to channel)
  send: (line) ->
    if @config.sendReplies then @lastRes.reply line else @lastRes.send line
    @record 'send', 'bot', line
    return

  # record and report sends, matches or mismatches
  # adds interactions to transcript if currently executing a named path
  record: (type, user, content, match, regex) ->
    @paths[@pathId].transcript.push [ type, user, content ] if @pathId?
    return switch type
      when 'match'
        @log.debug "Received \"#{ content }\" matched #{ inspect regex }"
        @emit 'match', user, content, match, regex
      when 'mismatch'
        @log.debug "Received \"#{ content }\" matched nothing"
        @emit 'mismatch', user, content
      when 'send'
        @log.debug "Sent \"#{ content }\""

  # shut it down - emit status for scene to disengage participants
  end: ->
    return false if @ended
    complete = @branches.length is 0
    @log.debug "Dialog ended #{ if not complete then 'in' }complete"
    @clearTimeout() if @countdown?
    @emit 'end', complete
    @ended = true
    return @ended

module.exports = Dialogue
