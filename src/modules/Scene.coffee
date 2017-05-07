_ = require 'lodash'
Base = require './Base'
Dialogue = require './Dialogue'

###*
 * Handle array of participants engaged in dialogue with bot
 * Credit to lmarkus/hubot-conversation for the original concept
 * Engaged bot will ignore global listeners, only respond to dialogue choices
 * - entering a user scene will engage the user
 * - entering a room scene will engage the whole room
 * - entering a direct scene will engage the user in that room only
 * @param  {Robot}  robot  - Hubot Robot instance
 * @param  {String} [type] - Type of scene: user(default)|room|direct
 * @param  {Object} [opts] - For dialogue config, e.g set reply method
###
class Scene extends Base
  constructor: (robot, args...) ->
    @type = if _.isString args[0] then args.shift() else 'user'
    @error "invalid scene type" if @type not in [ 'room', 'user', 'direct' ]

    super 'scene', robot, args...
    @Dialogue = Dialogue
    @engaged = {}

    # override default for room type only if not explicitly set
    @config.sendReplies ?= true if @type is 'room'

    # attach middleware
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
   * Identify the source of a message relative to the scene type
   * @param  {Response} res - Hubot Response object
   * @return {String}       - ID of room, user or composite
  ###
  whoSpeaks: (res) ->
    return switch @type
      when 'room' then return res.message.room.toString()
      when 'user' then return res.message.user.id.toString()
      when 'direct' then return "#{ res.message.user.id }_#{ res.message.room }"

  ###*
   * Engage the participants in dialogue
   * @param  {Response} res  - Hubot Response object
   * @param  {Object} [opts] - Options for dialogue, merged with scene config
   * @return {Dialogue}      - The started dialogue
  ###
  enter: (res, opts={}) ->
    participants = @whoSpeaks res
    return if @inDialogue participants
    dialogue = new @Dialogue res, _.defaults @config, opts
    dialogue.on 'timeout', (dlg, res) =>
      @exit res, 'timeout'
    dialogue.on 'end', (dlg, res) =>
      @exit res, "#{ if dlg.path?.closed then '' else 'in' }complete"
    @engaged[participants] = dialogue
    @emit 'enter', res, dialogue
    @log.info "Engaging #{ @type } #{ participants } in dialogue"
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
      @log.info "Disengaged #{ @type } #{ participants } (#{ status })"
      return true
    @log.debug "Cannot disengage #{ participants }, not in #{ @type } scene"
    return false

  ###*
   * End all engaged dialogues
  ###
  exitAll: ->
    @log.info "Disengaging all in #{ @type } scene"
    _.invokeMap @engaged, 'clearTimeout'
    @engaged = []
    return

  ###*
   * Get the dialogue for engaged participants (relative to scene type)
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
