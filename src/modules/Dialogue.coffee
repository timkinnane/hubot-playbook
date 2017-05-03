_ = require 'lodash'
Base = require './Base'
Path = require './Path'

###*
 * Controller for multiple-choice dialogue interactions
 * Credit to lmarkus/hubot-conversation for the original concept
 * @param  {Response} res   - Hubot Response object
 * @param  {Object} [opts]  - Key/val options for config
###
class Dialogue extends Base
  constructor: (@res, opts) ->
    @defaults =
      sendReplies: false # will send without addressing reply to sender
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutText: process.env.DIALOGUE_TIMEOUT_TEXT or
        'Timed out! Please start again.'
    super 'dialogue', @res.robot, opts
    @Path = Path
    @path = null
    @ended = false

  ###*
   * Shutdown and emit status (for scene to disengage participants)
   * @return {Boolean} - Shutdown status, false if was already ended
  ###
  end: ->
    return false if @ended
    if @path?
      @log.debug "Dialog ended #{ 'in' unless @path.closed }complete"
      @clearTimeout() if @countdown?
    else
      @log.debug "Dialog ended before paths added"
    @emit 'end', @res
    @ended = true
    return @ended

  ###*
   * Send or reply with message as configured (@user reply or send to room)
   * @param  {String} text Message text
   * TODO: return promise that resolves when robot reply/send completes process
   * TODO: update tests that wait for observer to use promise instead
  ###
  send: (text) ->
    if @config.sendReplies then @res.reply text else @res.send text
    @emit 'send', @res
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
   * Stop countdown for matching dialogue branches
  ###
  clearTimeout: ->
    clearTimeout @countdown
    delete @countdown
    return

  ###*
   * Start (or restart) countdown for matching dialogue branches
   * Catches the onTimeout method because it can be overriden and may throw
  ###
  startTimeout: ->
    clearTimeout() if @countdown?
    @countdown = setTimeout () =>
      @emit 'timeout', @res
      try @onTimeout() catch err then @error err
      delete @countdown
      @end()
    , @config.timeout
    return @countdown

  ###*
   * Add a dialogue path, with branches to follow and a prompt (optional)
   * @param  {String} [prompt]  - To send on path setup
   * @param  {Array} [branches] - Arguments for each brancch, each containing:
   *                              - regex for listener
   *                              - string for sending on match
   *                              AND/OR
   *                              - callback to fire on match
   * @param  {Object} [opts]    - Config key/vals
   * @return {Path}             - New path instance
   * TODO: when .send uses promise, return promise that resolves with @path
  ###
  addPath: (args...) ->
    prompt = args.shift() if _.isString args[0]
    branches = args.shift() if _.isArray args[0]
    opts = if _.isObject args[0] then opts = args.shift() else {}
    @path = new @Path @robot, branches, opts # current path overwrites previous
    @send prompt if prompt? # kick-off dialogue exchange
    @startTimeout() if branches?
    return @path

  ###*
   * Add a branch to dialogue path, which is usually added first, created if not
   * @param {RegExp}   regex      - Matching pattern
   * @param {String}   [message]  - Message text for response on match
   * @param {Function} [callback] - Function called when matched
  ###
  addBranch: (args...) ->
    @addPath() unless @path?
    @path.addBranch args...
    @startTimeout()
    return

  ###*
   * Process incoming message for match against path branches
   * If matched, fire handler, restart timeout
   * if no additional paths or branches added (by handler), end dialogue
   * Overrides the original response with current one
   * @param  {Response} res - Hubot Response object
   * TODO: Wrap handler in promise, don't end() until it resolves
   * TODO: Test with handler using res.http/get to populate new path
  ###
  receive: (@res) ->
    return false if @ended # dialogue is over, don't process
    @log.debug "Dialogue received #{ @res.message.text }"
    branch = @path.match @res
    if branch? and @res.match
      @clearTimeout()
      @emit 'match', @res
      branch.handler @res, @
    else if branch?
      @emit 'catch', @res
      branch.handler @res, @
    else
      @emit 'mismatch', @res
    @end() if @path.closed
    return

module.exports = Dialogue
