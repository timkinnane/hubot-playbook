# credit to lmarkus/hubot-conversation for the original concept
_ = require 'underscore'
{inspect} = require 'util'
Dialogue = require './Dialogue'

# handles array of participants engaged in dialogue
# while engaged the robot will only follow the given dialogue choices
# entering a user scene will engage the user
# entering a room scene will engage the whole room
# entering a userRoom scene will engage the user in that room only
# @param robot, a hubot instance
# @param type (optional), audience - room, user (default) or userRoom
class Scene
  constructor: (@robot, @type='user') ->
    if @type not in [ 'room', 'user', 'userRoom' ]
      throw new Error "invalid scene type given"

    @engaged = {} # dialogues of each engaged audience
    @log = @robot.logger

    # hubot middleware re-routes to internal matching while engaged
    @robot.receiveMiddleware (c, n, d) => @middleware @, c, n, d

  # not called as method, but copied as a property
  middleware: (scene, context, next, done) =>
    res = context.response
    audience = @whoSpeaks res

    # check if incoming messages are part of active scene
    if audience of scene.engaged
      scene.log.debug "#{ audience } is engaged in dialogue, routing dialogue."
      res.finish() # don't process regular listeners
      scene.engaged[audience].receive res # let dialogue handle the response
      done() # don't process further middleware.
    else
      scene.log.debug "#{ audience } not engaged, continue as normal."
      next done

  # return the source of a message (ID of user or room)
  whoSpeaks: (res) ->
    switch @type
      when 'room' then return res.message.room
      when 'user' then return res.message.user.id
      when 'userRoom' then return "#{res.message.user.id}_#{res.message.room}"

  # engage the audience in dialogue
  # @param res, the response object
  # @param options, key/vals for dialogue config, e.g overide timeout default
  enter: (res, opts={}) ->
    # extend options with defaults (passed to dialogue)
    opts = _.defaults opts,
      reply: if @type is 'room' then true else false # '@user hello' vs 'hello'

    # setup dialogue to handle choices for response branching
    audience = @whoSpeaks res
    return null if @inDialogue audience
    @log.info "Engaging #{ @type } #{ audience } in dialogue"
    @engaged[audience] = new Dialogue res, opts

    # remove audience from engaged participants on timeout or completion
    @engaged[audience].on 'timeout', => @exit res, 'timeout'
    @engaged[audience].on 'end', (completed) =>
      @exit res, "#{ if completed then 'complete' else 'incomplete' }"
    return @engaged[audience] # return started dialogue

  # disengage an audience from dialogue (can help in case of error)
  exit: (res, reason='unknown') ->
    audience = @whoSpeaks res
    if @engaged[audience]?
      @log.info "Disengaging #{ @type } #{ audience } because #{ reason }"
      @engaged[audience].clearTimeout()
      delete @engaged[audience]
      return true

    # user may have been already removed by timeout event before end:incomplete
    @log.debug "Cannot disengage #{ audience }, not in #{ @type } scene"
    return false

  # end all engaged dialogues
  # TODO: write tests
  exitAll: ->
    @log.info "Disengaging all in #{ @type } scene"
    _.invoke @engaged, 'clearTimeout'
    @engaged = []

  # return the dialogue for an engaged audience
  dialogue: (audience) -> return @engaged[audience] or null

  # return the engaged status for an audience
  inDialogue: (audience) -> return audience in _.keys @engaged

module.exports = Scene
