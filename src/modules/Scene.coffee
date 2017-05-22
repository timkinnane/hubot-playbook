_ = require 'lodash'
Base = require './Base'
Dialogue = require './Dialogue'

###*
 * Handle array of participants engaged in dialogue with bot
 * Credit to lmarkus/hubot-conversation for the original concept
 * Config keys:
 * - scope: How to address participants; user(default)|room|direct
 * - sendReplies: Toggle replying/sending (prefix message with "@user")
 * Engaged bot will ignore global listeners, only respond to dialogue choices
 * - entering a user scene will engage the user
 * - entering a room scene will engage the whole room
 * - entering a direct scene will engage the user in that room only
 * @param {Robot}  robot     - Hubot Robot instance
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Scene extends Base
  constructor: (robot, args...) ->
    @config = scope: 'user'
    super 'scene', robot, args...
    @config.sendReplies ?= true if @config.scope is 'room'

    validTypes = [ 'room', 'user', 'direct' ]
    @error "invalid scene scope" if @config.scope not in validTypes

    @Dialogue = Dialogue
    @engaged = {}
    @robot.receiveMiddleware (c, n, d) => @middleware.call @, c, n, d

  ###*
   * Process incoming messages, re-route to dialogue for engaged participants
   * @param  {Object}   context - Passed through the middleware stack, with res
   * @param  {Function} next    - Called when all middleware is complete
   * @param  {Function} done    - Initial (final) completion callback
  ###
  middleware: (context, next, done) ->
    res = context.response
    participants = @whoSpeaks res

    # are incoming messages from this scenes' engaged participants
    if participants of @engaged
      @log.debug "#{ participants } is engaged, routing dialogue."
      res.finish() # don't process regular listeners
      @engaged[participants].receive res # let dialogue handle the response
      done() # don't process further middleware.
    else
      @log.debug "#{ participants } not engaged, continue as normal."
      next done
    return

  ###*
   * Add listener with callback to enter scene
   * @param  {String} type       - The listener type: hear|respond
   * @param  {RegExp} regex      - Matcher for listener
   * @param  {Function} callback - Callback to fire when matched
  ###
  listen: (type, regex, callback) ->
    @error "Invalid listener type" if type not in ['hear', 'respond']
    @error "Invalid regex for listener" if not _.isRegExp regex
    @error "Invalid callback for listener" if not _.isFunction callback

    # setup listener with scene as attribute for later/external reference
    @robot[type] regex, id: @id, scene: @, (res) =>
      dialogue = @enter res # may fail if enter hooks override (from Director)
      callback res, dialogue if dialogue?
    return

  ###*
   * Alias of .listen with hear as specified type
  ###
  hear: (args...) -> return @listen 'hear', args...

  ###*
   * Alias of .listen with respond as specified type
  ###
  respond: (args...) -> return @listen 'respond', args...

  ###*
   * Identify the source of a message relative to the scene scope
   * @param  {Response} res - Hubot Response object
   * @return {String}       - ID of room, user or composite
  ###
  whoSpeaks: (res) ->
    return switch @config.scope
      when 'room' then return res.message.room.toString()
      when 'user' then return res.message.user.id.toString()
      when 'direct' then return "#{ res.message.user.id }_#{ res.message.room }"

  ###*
   * Engage the participants in dialogue
   * @param  {Response} res       - Hubot Response object
   * @param  {Object}   [options] - Dialogue options merged with scene config
   * @param  {Mixed}    args      - Any additional args for Dialogue constructor
   * @return {Dialogue}           - The started dialogue
  ###
  enter: (res, args...) ->
    participants = @whoSpeaks res
    return if @inDialogue participants
    options = if _.isObject args[0] then args.shift() else {}
    options = _.defaults {}, @config, options
    dialogue = new @Dialogue res, options, args...
    dialogue.on 'timeout', (dlg, res) =>
      @exit res, 'timeout'
    dialogue.on 'end', (dlg, res) =>
      @exit res, "#{ if dlg.path?.closed then '' else 'in' }complete"
    @engaged[participants] = dialogue
    @emit 'enter', res, dialogue
    @log.info "Engaging #{ @config.scope } #{ participants } in dialogue"
    return dialogue

  ###*
   * Disengage participants from dialogue e.g. in case of timeout or error
   * @param  {Response} res    - Hubot
   * @param  {String} [status] - Some context, for logs
   * @return {Boolean}         - Exit success (may fail if already disengaged)
  ###
  exit: (res, status) ->
    status ?= 'unknown'
    participants = @whoSpeaks res
    if @engaged[participants]?
      @engaged[participants].clearTimeout()
      delete @engaged[participants]
      @emit 'exit', res, status
      @log.info "Disengaged #{ @config.scope } #{ participants } (#{ status })"
      return true
    @log.debug "Cannot disengage #{ participants }, not in scene"
    return false

  ###*
   * End all engaged dialogues
  ###
  exitAll: ->
    @log.info "Disengaging all in #{ @config.scope } scene"
    _.invokeMap @engaged, 'clearTimeout'
    @engaged = []
    return

  ###*
   * Get the dialogue for engaged participants (relative to scene scope)
   * @param  {String} participants - ID of user, room or composite
   * @return {Dialogue}            - Engaged dialogue instance
  ###
  getDialogue: (participants) ->
    return @engaged[participants]

  # return the engaged status for an participants
  ###*
   * Get the engaged status for participants
   * @param  {String} participants - ID of user, room or composite
   * @return {Boolean}             - Is engaged status
  ###
  inDialogue: (participants) ->
    return participants in _.keys @engaged

module.exports = Scene
