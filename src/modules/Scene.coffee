# credit to lmarkus/hubot-conversation for the original concept
_ = require 'underscore'

Dialogue = require './Dialogue'
Helpers = require './Helpers'

# handles array of participants engaged in dialogue
# while engaged the robot will only follow the given dialogue choices
# entering a user scene will engage the user
# entering a room scene will engage the whole room
# entering a direct scene will engage the user in that room only
class Scene

  # @param robot {Object} a hubot instance
  # @param type (optional) {String} room, user (default) or direct
  # @param opts (optional) {Object} for dialogue config, e.g set reply method
  constructor: (@robot, args...) ->

    # take arguments in param order, for all optional arguments
    @type = if _.isString args[0] then args.shift() else 'user'
    opts = if _.isObject args[0] then args.shift() else {}

    if @type not in [ 'room', 'user', 'direct' ]
      throw new Error "invalid scene type given"

    # create an id using scene scope (and key if given)
    @id = Helpers.keygen 'scene', opts.key or undefined

    # '@user hello' vs 'hello'
    sendReplies = if @type is 'room' then true else false

    # extend options with defaults (or env vars) (passed to dialogue)
    @config = _.defaults opts,
      sendReplies: process.env.SEND_REPLIES or sendReplies

    # cast send config as proper bool in case string came from environment var
    @config.sendReplies = true if @config.sendReplies in ['true', 'TRUE']
    @config.sendReplies = false if @config.sendReplies in ['false', 'FALSE']

    @engaged = {} # dialogues of each engaged participant type
    @log = @robot.logger # shorthand helper

    # attach middleware
    @robot.receiveMiddleware (c, n, d) => @middleware.call @, c, n, d

  # process all incoming messages, re-route to dialogue for engaged participants
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

  # setup listener callback to enter scene
  # @param type - the listener type, should be hear or respond
  # @param
  listen: (type, args...) ->
    throw new Error "Invalid listener type" if type not in ['hear','respond']

    # valid regex as first arg (required)
    regex = args.shift()
    throw new Error "Invalid regex for listener" if not _.isRegExp regex

    # create id from scene namespace and listener scope (and key if provided)
    if _.isString args[0]
      id = Helpers.keygen @id+'_listener', args.shift()
    else
      id = Helpers.keygen @id+'_listener'

    # last arg taken as callback (required)
    callback = args.shift()
    throw new Error "Invalid callback for listener" if not _.isFunction callback

    # setup robot listener with given or generated key, so it can be referred to
    @robot[type] regex, id: id, (res) =>
      dialogue = @enter res # may fail if enter hooks override (from Director)
      callback.call dialogue, res if dialogue? # in callback dialogue is 'this'
      # callback res, dialogue if dialogue? # TODO

    return id

  # alias of .listen with hear as specified type
  hear: (args...) -> return @listen 'hear', args...

  # alias of .listen with respond as specified type
  respond: (args...) -> return @listen 'respond', args...

  # return the source of a message (ID of user or room)
  whoSpeaks: (res) ->
    return switch @type
      when 'room' then return res.message.room
      when 'user' then return res.message.user.id
      when 'direct' then return "#{res.message.user.id}_#{res.message.room}"

  # engage the participants in dialogue
  # @param res, the response object
  # @param opts (optional), key/vals for dialogue config, e.g overide timeout
  enter: (res, opts={}) ->

    # extend dialogue options with scene config
    opts = _.defaults @config, opts

    # setup dialogue to handle choices for response branching
    participants = @whoSpeaks res
    return null if @inDialogue participants
    @log.info "Engaging #{ @type } #{ participants } in dialogue"
    @engaged[participants] = new Dialogue res, opts

    # remove participants from engaged participants on timeout or completion
    @engaged[participants].on 'timeout', => @exit res, 'timeout'
    @engaged[participants].on 'end', (completed) =>
      @exit res, "#{ if completed then 'complete' else 'incomplete' }"
    return @engaged[participants] # return started dialogue

  # disengage an participants from dialogue (can help in case of error)
  exit: (res, reason='unknown') ->
    participants = @whoSpeaks res
    if @engaged[participants]?
      @log.info "Disengaging #{ @type } #{ participants } because #{ reason }"
      @engaged[participants].clearTimeout()
      delete @engaged[participants]
      return true

    # user may have been already removed by timeout event before end:incomplete
    @log.debug "Cannot disengage #{ participants }, not in #{ @type } scene"
    return false

  # end all engaged dialogues
  exitAll: ->
    @log.info "Disengaging all in #{ @type } scene"
    _.invoke @engaged, 'clearTimeout'
    @engaged = []
    return

  # return the dialogue for an engaged participants
  dialogue: (participants) -> return @engaged[participants] or null

  # return the engaged status for an participants
  inDialogue: (participants) -> return participants in _.keys @engaged

module.exports = Scene
