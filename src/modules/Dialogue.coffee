_ = require 'lodash'
Base = require './Base'

###*
 * Multiple-choice dialogue interactions
 * Credit to lmarkus/hubot-conversation for the original concept
 * @param  {Response} res   - Hubot Response object
 * @param  {Object} [opts]  - Key/val options for config
###
class Dialogue extends Base
  defaults:
    sendReplies: false # will send without addressing reply to sender
    timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
    timeoutText: process.env.DIALOGUE_TIMEOUT_TEXT or
      'Timed out! Please start again.'

  constructor: (res, opts) ->
    super 'dialogue', res.robot, opts
    @lastRes = res # lastRes may be updated, res is initiating response
    @paths = {} # builds as dialogue progresses
    @pathId = null # pointer for current path
    @branches = [] # branch options within current path
    @ended = false # state of dialogue completion

  ###*
   * Start countdown for matching dialogue branches
   * Catches the onTimeout method because it can be overriden and may throw
  ###
  startTimeout: ->
    @countdown = setTimeout () =>
      @emit 'timeout'
      try @onTimeout() catch err then @handle err
      delete @countdown
      @end()
    , @config.timeout
    return @countdown

  ###*
   * Stop countdown for matching dialogue branches
  ###
  clearTimeout: ->
    clearTimeout @countdown
    delete @countdown
    return

  ###*
   * Default timeout method sends message, unless null or method overriden
   * If given a method it will call that or can be reassigned as a new function
   * @param  {Function} [override] - New function to call (optional)
  ###
  onTimeout: (override) ->
    if override?
      @onTimeout = override
    else
      @send @config.timeoutText if @config.timeoutText?
    return

  ###*
   * Add a dialogue path, a prompt with one or more branches to follow
   * @param  {Array} branches - Arguments for each brancch, each containing:
   *                            - regex for listener
   *                            - string for sending on match OR
   *                            - callback to fire on match
   * @param  {Object} [opts]  - Options...
   *                            - [key] source for path ID
   *                            - [prompt] to send on setup
   * @return {String} Key (either the given or computed) for future reference
  ###
  path: (branches, opts) ->
    @pathId = @keygen 'path_' + opts.key or opts.prompt

    # setup new path object and dialogue state
    # TODO store actual branch instances instead of status, get status from that
    @clearBranches()
    @paths[@pathId] =
      prompt: opts.prompt
      status: _.map branches, (args) => @branch args...
      transcript: []

    # kick-off dialogue exchange
    @send opts.prompt if opts.prompt?
    return @pathId # allow path to be queried by key

  ###*
   * Add a dialogue branch (usually through path)
   * Can be called with message for response or callback, or both
   * @param  {RegExp}   regex      - Matcher
   * @param  {String}   [message]  - Response text
   * @param  {Function} [callback] - Call when matched
   * @return {Boolean}             Status of the branch
   * TODO refactor as class
  ###
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
      @log.error "Wrong args given for branch with regex #{ regex }"
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

  ###*
   * Remove any and all current branches
  ###
  clearBranches: ->
    @branches = []
    return

  ###*
   * Match on incoming, deliver response, restart timeout and end dialogue
   * @param  {Response} res Hubot Response object
  ###
  receive: (res) ->
    return false if @ended # dialogue is over, don't process

    text = res.message.text
    @log.debug "Dialogue received #{ text }"
    match = false

    # stop at the first match in the order in which they were added
    @branches.some (branch) =>
      if match = text.match branch.regex
        # match found, clear this step
        @record 'match', res.message.user, text, match, branch.regex
        @clearBranches()
        @clearTimeout()
        res.match = match # override the original match from hubot listener
        @lastRes = res # override the original response with current one
        branch.handler res # may add additional branches / restarting timeout
        return true # don't process further matches

    # record and report if nothing matched
    @record 'mismatch', res.message.user, text if not match
    @end() if @branches.length is 0 # end if nothing left to do
    return

  ###*
   * Send or reply with message as configured (@user reply or send to room)
   * @param  {String} text Message text
  ###
  send: (text) ->
    if @config.sendReplies then @lastRes.reply text else @lastRes.send text
    @record 'send', 'bot', text
    return

  ###*
   * Emit event and add to transcript if currently executing a named path
   * @param  {String} type    - Event type in context: send|match|mismatch
   * @param  {User}   user    - Hubot User object
   * @param  {String} text    - Message text
   * @param  {Array} [match]  - Match results
   * @param  {RegExp} [regex] - Matching expression
  ###
  record: (type, user, text, match, regex) ->
    @paths[@pathId].transcript.push [ type, user, text ] if @pathId?
    switch type
      when 'match'
        @log.debug "Received \"#{ text }\" matched #{ regex }"
        @emit 'match', user, text, match, regex
      when 'mismatch'
        @log.debug "Received \"#{ text }\" matched nothing"
        @emit 'mismatch', user, text
      when 'send'
        @log.debug "Sent \"#{ text }\""
    return

  ###*
   * Shutdown and emit status (for scene to disengage participants)
   * @return {Boolean} - Shutdown status, false if was already ended
  ###
  end: ->
    return false if @ended
    complete = @branches.length is 0
    @log.debug "Dialog ended #{ if not complete then 'in' }complete"
    @clearTimeout() if @countdown?
    @emit 'end', complete
    @ended = true
    return @ended

module.exports = Dialogue
