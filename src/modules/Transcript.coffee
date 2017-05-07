_ = require 'lodash'
Base = require './Base'

_.mixin 'hasKeys': (obj, keys) ->
  return false unless _.isObject obj
  return 0 is _.size _.difference keys, _.keys obj
_.mixin 'hasPaths': (obj, paths) ->
  return false unless _.isObject obj
  return _.every paths, (path) -> _.hasIn obj, path
_.mixin 'mapPaths': (src, paths) ->
  dest = {}
  _.each paths, (path) -> dest[path.split('.').pop()] = _.head _.at src, path
  return dest

###
  TODO: move to docs...
  For reference, these are the event types and args used by Playbook and Hubot:
  ```
  Robot
                error       Error
                running     -
  Robot.brain
                loaded      data
                save        data
                close       -
  Robot.adapter
                connected
  ```
  ```
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
  ```
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
      responseAtts: [
        'message.user.id'
        'message.user.name'
        'message.text'
        'message.room'
      ]
      instanceAtts: [
        'name'
        'config.key'
        'id'
      ]

    super 'transcript', robot, opts
    @records = @robot.brain.get 'transcripts' if @config.save
    @records ?= []

  # TODO: get all events for user, or by user and instance key if given
  # e.g. getRecords joeUser, 'favourite-colour'

  ###*
   * Record given event in records array, save to hubot brain if configured
   * Events emitted by Playbook always include module instance as first param
   * @param  {String} event   - The event name
   * @param  {Mixed} args...  - Args passed with the event, usually consists of:
   *                            - Playbook module instance
   *                            - Hubot response object
   *                            - other additional (special context) arguments
  ###
  recordEvent: (event, args...) ->
    instance = args.shift() if _.hasKeys args[0], ['name', 'id', 'config']
    response = args.shift() if _.hasKeys args[0], ['robot', 'message']

    record = time: _.now(), event: event
    record.key = @config.key if @config.key?
    record.instance = _.mapPaths instance, @config.instanceAtts if instance?
    record.response = _.mapPaths response, @config.responseAtts if response?
    record.other = args unless _.isEmpty args

    @records.push record
    @robot.brain.save()
    return

  ###*
   * Record events emitted by all Playbook modules and/or the robot itself
   * (still only applies to configured event types)
  ###
  recordAll: ->
    _.each _.castArray(@config.events), (event) =>
      @robot.on event, (args...) => @recordEvent event, args...
    return

  ###*
   * Record events emitted by a given dialogue
   * @param  {Dialogue} dialogue The Dialogue instance
  ###
  recordDialogue: (dialogue) ->
    _.each _.castArray(@config.events), (event) =>
      dialogue.on event, (args...) => @recordEvent event, args...
    return

  ###*
   * Record events emitted by a given scene and any dialogue it enters
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
   * Record denial events emitted by a given director
   * Ignores configured events because director has distinct events
   * @param  {Director} scene The Director instance
  ###
  recordDirector: (director) ->
    director.on 'allow', (args...) =>
      @recordEvent 'allow', args...
    director.on 'deny', (args...) =>
      @recordEvent 'deny', args...
    return

module.exports = Transcript
