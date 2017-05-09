_ = require 'lodash'
Base = require './Base'

_.mixin 'hasKeys': (obj, keys) ->
  return false unless _.isObject obj
  return 0 is _.size _.difference keys, _.keys obj
_.mixin 'hasPaths': (obj, paths) ->
  return false unless _.isObject obj
  return _.every paths, (path) -> _.hasIn obj, path

###*
 * Keep a record of events and Playbook conversation attributes
 * Transcript can record all events on the Robot or a specified module instance
 * @param {Robot}  robot  - Hubot Robot instance
 * @param {Object} [opts] - Config options:
 *                          key: for grouping records
 *                          events: array of event names to record
 *                          responseAtts: Hubot Response attribute paths (array)
 *                          to record from each event containing a response;
 *                          defaults keep message and match subpaths
 *                          instanceAtts: as above, for Playbook module atts
 *                          defaults keep name, key and id
###
class Transcript extends Base
  constructor: (robot, opts) ->
    @defaults =
      save: true
      events: ['match', 'mismatch', 'catch', 'send']
      instanceKeys: []
      instanceAtts: ['name', 'config.key', 'id' ]
      responseAtts: ['match']
      messageAtts: ['user.id', 'user.name', 'room', 'text']

    super 'transcript', robot, opts
    if 'record' in @config.events
      @error 'cannot record record event - infinite loop'
    @records = @robot.brain.get 'transcripts' if @config.save
    @records ?= []

  ###*
   * TODO: TEST instanceKeys
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

    if _.size @config.instanceKeys
      return unless instance?
      return unless instance.config.key in @config.instanceKeys

    record = time: _.now(), event: event
    record.key = @config.key if @config.key?
    record.instance = _.pick instance, @config.instanceAtts if instance?
    record.response = _.pick response, @config.responseAtts if response?
    record.message = _.pick response.message, @config.messageAtts if response?
    record.other = args unless _.isEmpty args

    @records.push record
    @emit 'record', record
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

  # Filter records matching a subset, e.g. user name or instance key
  # Optionally return the whole record or values for a given key
  # e.g. findRecords
  #  'message.name': 'joe'
  #  'instance.key': 'favourite-colour'
  # ], 'match'
  findRecords: (subsetMatch, returnPath) ->
    found = _.filter @records, subsetMatch
    return found unless returnPath?
    return _.map found, (record) -> _.at record, returnPath

module.exports = Transcript
