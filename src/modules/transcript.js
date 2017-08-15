import _ from 'lodash'
import Base from './base'

_.mixin({
  'hasKeys': (obj, keys) => _.size(_.difference(keys, _.keys(obj))) === 0
})
_.mixin({
  'pickHas': (obj, pickKeys) => _.omitBy(_.pick(obj, pickKeys), _.isUndefined)
})

/**
 * Records conversation events, including meta about the user, message and
 * current module state. It is configurable to provide an overview or drilled
 * down analytics of specific interactions.
 *
 * Transcripts are searchable, to provide context to interactions from
 * conversation history with a given user of any other attribute. If saving to
 * the hubot brain, they will also search from the brain's persisted transcript
 * history.
 *
 * It can record all events emitted through the robot or just those originating
 * from a given Playbook module instance
 *
 * @param {Robot}  robot                  Hubot Robot instance
 * @param {Object} [options]              Key/val options for config
 * @param {Object} [options.save]         Store records in hubot brain
 * @param {Object} [options.events]       Array of event names to record
 * @param {Object} [options.responseAtts] Hubot Response attribute keys to add to record
 * @param {Object} [options.instanceAtts] Module instance attribute keys to add to record
 * @param {string} [key]     Key name for this instance
 *
 * @example <caption>transcript to record room name when match emitted</caption>
 * let matchRecords = new Transcript(robot, {
 *   responseAtts: ['message.room']
 *   events: ['match']
 * })
 * // does not start recording until calling one of the record methods, like:
 * matchRecords.recordAll()
*/
class Transcript extends Base {
  constructor (...args) {
    super('transcript', ...args)
    this.defaults({
      save: true,
      events: ['match', 'mismatch', 'catch', 'send'],
      instanceAtts: ['name', 'key', 'id'],
      responseAtts: ['match'],
      messageAtts: ['user.id', 'user.name', 'room', 'text']
    })
    if (this.config.instanceAtts != null) _.castArray(this.config.instanceAtts)
    if (this.config.responseAtts != null) _.castArray(this.config.responseAtts)
    if (this.config.messageAtts != null) _.castArray(this.config.messageAtts)

    if (this.config.save) {
      if (!this.robot.brain.get('transcripts')) {
        this.robot.brain.set('transcripts', [])
      }
      this.records = this.robot.brain.get('transcripts')
    }
    if (this.records == null) this.records = []
  }

  /**
   * Record given event details in array, save to hubot brain if configured to
   * Events emitted by Playbook always include module instance as first param.
   *
   * @param  {string} event   The event name
   * @param  {Mixed} args...  Args passed with the event, usually consists of:<br>
   *                          - Playbook module instance<br>
   *                          - Hubot response object<br>
   *                          - other additional (special context) arguments
  */
  recordEvent (event, ...args) {
    let instance, response
    if (_.hasKeys(args[0], ['name', 'id', 'config'])) instance = args.shift()
    if (_.hasKeys(args[0], ['robot', 'message'])) response = args.shift()
    const record = {time: _.now(), event}
    if (this.key != null) record.key = this.key

    if ((instance != null) && (this.config.instanceAtts != null)) {
      record.instance = _.pickHas(instance, this.config.instanceAtts)
    }
    if ((response != null) && (this.config.responseAtts != null)) {
      record.response = _.pickHas(response, this.config.responseAtts)
    }
    if ((response != null) && (this.config.messageAtts != null)) {
      record.message = _.pickHas(response.message, this.config.messageAtts)
    }

    // TODO
    // Strings are sent as additional args for sends, because dialogues can't get
    // access to the generated response object without adding middleware, they
    // only have the user's response being replied to, otherwise the robot's text
    // is lost.
    // Once middleware returns a promise, it should resolve with the new
    // response object sent by the robot, then send should be emitted with that
    // so keeping the strings as an additional property won't be required and the
    // records will be more consistently structured for querying an interaction
    if (!_.isEmpty(args)) {
      if (event === 'send') record.strings = args
      else record.other = args
    }

    this.records.push(record)
    this.emit('record', record)
  }

  /**
   * Record events emitted by all Playbook modules and/or the robot itself
   * (still only applies to configured event types).
  */
  recordAll () {
    _.castArray(this.config.events).map((event) =>
      this.robot.on(event, (...args) =>
        this.recordEvent(event, ...args))
    )
  }

  /**
   * Record events emitted by a given dialogue.
   *
   * @param {Dialogue} dialogue The Dialogue instance
  */
  recordDialogue (dialogue) {
    _.castArray(this.config.events).map((event) =>
      dialogue.on(event, (...args) =>
        this.recordEvent(event, ...args))
    )
  }

  /**
   * Record events emitted by a given scene and any dialogue it enters, captures
   * all events fromn the scene but only configured events from dialogue.
   *
   * @param {Scene} scene The Scnee instance
  */
  recordScene (scene) {
    scene.on('enter', (scene, res, dialogue) => {
      this.recordEvent('enter', scene, res)
      this.recordDialogue(dialogue)
    })
    scene.on('exit', (...args) => this.recordEvent('exit', ...args))
  }

  /**
   * Record allow/deny events emitted by a given director. Ignores configured
   * events because director has distinct events.
   *
   * @param {Director} scene The Director instance
  */
  recordDirector (director) {
    director.on('allow', (...args) => this.recordEvent('allow', ...args))
    director.on('deny', (...args) => this.recordEvent('deny', ...args))
  }

  /**
   * Filter records matching a subset, e.g. user name or instance key.
   *
   * Optionally return the whole record or values for a given key.
   *
   * @param  {Object} subsetMatch  Key/s:value/s to match (accepts path key)
   * @param  {string} [returnPath] Key or path within record to return
   * @return {array}               Whole records or selected values found
   *
   * @example
   * transcript.findRecords({
   *   message: { user: { name: 'jon' } }
   * })
   * // returns array of event objects
   *
   * transcript.findRecords({
   *   message: { user: { name: 'jon' } }
   * }, 'message.text')
   * // returns array of message text only
  */
  findRecords (subsetMatch, returnPath) {
    const found = _.filter(this.records, subsetMatch)
    if (returnPath == null) return found
    return found.map((record) => _(record).at(returnPath).head())
  }

  /**
   * Shortcut for findRecords for just response match attributes, with a given
   * instance key, useful for simple lookups of information provided by user
   * within a specific conversation.
   *
   * @param  {string}  instanceKey From the recorded instance to lookup
   * @param  {integer} [capture]   Filter match by regex capture group subset
   * @return {array}               Contains full match or just capture group
   * @todo option filter by ID - e.g. only searching current module interactions
   * @todo option filter by User
   *
   * @example <caption>find answers from a specific dialogue path</caption>
   * let colorMatches = transcript.findKeyMatches('pick-a-color', 0)
   * let latestColor = colorMatches[0]
  */
  findKeyMatches (instanceKey, captureGroup) {
    const subset = {instance: {key: instanceKey}}
    let path = 'response.match'
    if (captureGroup != null) path += `[${captureGroup}]`
    return this.findRecords(subset, path)
  }
}

export default Transcript
