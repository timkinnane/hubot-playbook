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
 * @param  {Robot}  @robot - Hubot Robot instance
 * @param  {String} [type] - Type of scene: user(default)|room|direct
 * @param  {Object} [opts] - For dialogue config, e.g set reply method
###
class Scene extends Base
  constructor: (robot, args...) ->
    @type = if _.isString args[0] then args.shift() else 'user'
    @handle "invalid scene type" if @type not in [ 'room', 'user', 'direct' ]

    super 'scene', robot, args...
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
   * @return {String}            - Generated ID for listener
  ###
  listen: (type, regex, callback) ->
    @handle "Invalid listener type" if type not in ['hear','respond']
    @handle "Invalid regex for listener" if not _.isRegExp regex
    @handle "Invalid callback for listener" if not _.isFunction callback

    # setup robot listener with generated ID, for later/external reference
    id = @keygen 'listener'
    @robot[type] regex, id: id, (res) =>
      dialogue = @enter res # may fail if enter hooks override (from Director)
      callback res, dialogue if dialogue?
    return id

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
      when 'room' then return res.message.room
      when 'user' then return res.message.user.id
      when 'direct' then return "#{res.message.user.id}_#{res.message.room}"

  ###*
   * Engage the participants in dialogue
   * @param  {Response} res  - Hubot Response object
   * @param  {Object} [opts] - Options for dialogue, merged with scene config
   * @return {Dialogue}      - The started dialogue
  ###
  enter: (res, opts={}) ->
    participants = @whoSpeaks res
    return null if @inDialogue participants
    @log.info "Engaging #{ @type } #{ participants } in dialogue"
    @engaged[participants] = new Dialogue res, _.defaults @config, opts
    @engaged[participants].on 'timeout', => @exit res, 'timeout'
    @engaged[participants].on 'end', (completed) =>
      @exit res, "#{ if completed then 'complete' else 'incomplete' }"
    return @engaged[participants]

  ###*
   * Disengage participants from dialogue e.g. in case of timeout or error
   * @param  {Response} res    - Hubot
   * @param  {String} [reason] - Some context, for logs
   * @return {Boolean}         - Exit success (may fail if already disengaged)
  ###
  exit: (res, reason) ->
    reason ?= 'unknown'
    participants = @whoSpeaks res
    if @engaged[participants]?
      @log.info "Disengaging #{ @type } #{ participants } because #{ reason }"
      @engaged[participants].clearTimeout()
      delete @engaged[participants]
      return true
    @log.debug "Cannot disengage #{ participants }, not in #{ @type } scene"
    return false

  ###*
   * End all engaged dialogues
  ###
  exitAll: ->
    @log.info "Disengaging all in #{ @type } scene"
    _.invoke @engaged, 'clearTimeout'
    @engaged = []
    return

  ###*
   * Get the dialogue for engaged participants (relative to scene type)
   * @param  {String} participants - ID of user, room or composite
   * @return {Dialogue}            - Engaged dialogue instance
  ###
  dialogue: (participants) ->
    return @engaged[participants] or null

  # return the engaged status for an participants
  ###*
   * Get the engaged status for participants
   * @param  {String} participants - ID of user, room or composite
   * @return {Boolean}             - Is engaged status
  ###
  inDialogue: (participants) ->
    return participants in _.keys @engaged

module.exports = Scene
