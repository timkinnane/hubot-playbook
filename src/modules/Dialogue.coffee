_ = require 'lodash'
Base = require './Base'
Path = require './Path'

###*
 * Controller for multiple-choice dialogue interactions
 * Credit to lmarkus/hubot-conversation for the original concept
 * Config keys:
 * - sendReplies: Toggle replying/sending (prefix message with "@user")
 * - timeout: Allowed time to reply (in miliseconds) before cancelling listeners
 * - timeoutText: What to send when timeout reached, set null to not send
 * @param {Response} res     - Hubot Response object
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Dialogue extends Base
  constructor: (@res, args...) ->
    @config =
      sendReplies: false
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutText: process.env.DIALOGUE_TIMEOUT_TEXT or
        'Timed out! Please start again.'
    super 'dialogue', @res.robot, args...
    @Path = Path
    @path = null
    @ended = false

  ###*
   * Shutdown and emit status (for scene to disengage participants)
   * @return {Boolean} - Shutdown status, false if was already ended
  ###
  end: ->
    return false if @ended
    @clearTimeout() if @countdown?
    if @path?
      @log.debug "Dialog ended #{ if @path.closed then '' else 'in' }complete"
    else
      @log.debug "Dialog ended before paths added"
    @emit 'end', @res
    @ended = true
    return @ended

  ###*
   * Send or reply with message as configured (@user reply or send to room)
   * @param {String} strings Message strings
   * TODO: return promise that resolves when robot reply/send completes process
   * TODO: update tests that wait for observer to use promise instead
  ###
  send: (strings...) ->
    if @config.sendReplies
      sent = @res.reply strings...
    else
      sent = @res.send strings...
    @emit 'send', @res, strings...
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
   * Any new path added overwrites the previous
   * @param  {String} [prompt]   - To send on path setup
   * @param  {Array}  [branches] - Arguments for each brancch containing:
   *                               - regex for listener
   *                               - string for sending on match AND/OR
   *                               - callback to fire on match
   * @param {Object} [options]   - Key/val options for path
   * @param {String} [key]       - Key name for this path
   * @return {Path}              - New path instance
   * TODO: when .send uses promise, return promise that resolves with @path
  ###
  addPath: (args...) ->
    @send args.shift() if _.isString args[0]
    @path = new @Path @robot, args...
    @startTimeout() if @path.branches.length
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
