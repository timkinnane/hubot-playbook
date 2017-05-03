_ = require 'lodash'
Base = require './Base'

###
  TODO: move to docs...
  For reference, these are the event types and args used by Playbook and Hubot:

  Robot
                error       Error
                running     -
  Robot.brain
                loaded      data
                save        data
                close       -
  Robot.adapter
                connected
  Dialogue
                end         Dialogue, Response
                send        Dialogue, Response
                timeout     Dialogue, Response
                match       Dialogue, Response
                catch       Dialogue, Response
                mismatch    Dialogue, Response
  Scene
                enter       Scene, Response, Dialogue
                exit        Scene, Response, status(complete|incomplete|timeout)
  Director
                denied      Dialogue, Response
###

###*
 * Keep a record of events and Playbook conversation attributes
 * Transcript can record all events on the Robot or a specified module instance
 * @param {Robot}  robot  - Hubot Robot instance
 * @param {Object} [opts] - Config options:
 *                          key: for grouping records
 *                          events: array of event names to record
 *                          responseAtts: Hubot Response attribute paths (array)
 *                          to record from each event containing a response;
 *                          defaults keep res.user.name and res.message.text
 *                          instanceAtts: as above, for Playbook module atts
 *                          defaults keep name, key and id
###
class Transcript extends Base
  constructor: (robot, opts) ->
    @defaults =
      save: true
      events: ['match', 'mismatch', 'catch', 'send']
      responseAtts: ['user.name', 'message.text']
      instanceAtts: ['name', 'config.key', 'id']

    super 'transcript', robot, opts
    @records = @robot.brain.get 'transcripts' if @config.save
    @records ?= []

  ###*
   * Record events emmitted by all Playbook modules and/or the robot itself
   * (still only applies to configured event types)
  ###
  recordAll: ->
    _.each @config.events, (event) =>
      @robot.on event, (args...) => @recordEvent event, args...
    return

  ###*
   * Record events emmitted by a given dialogue
   * @param  {Dialogue} dialogue The Dialogue instance
  ###
  recordDialogue: (dialogue) ->
    _.each @config.events, (event) =>
      dialogue.on event, (args...) => @rerecordEvent event, args...
    return

  ###*
   * Record events emmitted by a given scene and any dialogue it enters
   * Records all events fromn the scene but only configured events from dialogue
   * @param  {Scene} scene The Scnee instance
  ###
  recordScene: (scene) ->
    scene.on 'enter', (scene, res, dialogue) =>
      @recordEvent 'enter', scene, res
      @recordDialogue dialogue
    scene.on 'exit', (scene, res, reason) =>
      @recordEvent 'exit', scene, res, reason
    return

  ###*
   * Record denial events emmitted by a given director
   * Ignores configured events because director has distinct events
   * @param  {Director} scene The Director instance
  ###
  recordDirector: (director) ->
    director.on 'denied', (args...) => @recordEvent 'denied', director, args...
    return

  ###*
   * Record given event in records array, save to hubot brain if configured
   * Events emitted by Playbook always include the module instance as first param
   * @param  {String} event   - The event name
   * @param  {Mixed} args...  - Args passed with the event, usually consists of:
   *                            - Playbook module instance
   *                            - Hubot response object
   *                            - other additional (special context) arguments
  ###
  recordEvent: (event, args...) ->
    instance = args.shift() if _.has args[0], ['name', 'id', 'config']
    res = args.shift() if _.has args[0], ['user', 'message']
    other = args if args.length?

    record = time: now(), event: event
    record.key = @config.key if @config.key?
    if instance?
      _.each @config.instanceAtts, (path) -> record[path] = _.at instance, path
    if res?
      _.each @config.responseAtts, (path) -> record[path] = _.at res, path
    record.other = other if other?

    @records.push record
    @robot.brain.save()
    console.log @robot.brain
    return

module.exports = Transcript
