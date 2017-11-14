'use strict'

const _ = require('lodash')
const Base = require('./base')

_.mixin({
  'hasKeys': (obj, keys) => _.size(_.difference(keys, _.keys(obj))) === 0
})
_.mixin({
  'pickHas': (obj, pickKeys) => _.omitBy(_.pick(obj, pickKeys), _.isUndefined)
})

/**
 * Transcripts record conversation events, including meta about the user,
 * message and current module.
 *
 * Transcripts are searchable, to provide context from conversation history with
 * a given user, or based on any other attribute, such as listener ID.
 *
 * Different instances can be configured to record an overview or drilled down
 * analytics for a specific module’s interactions using its key.
 *
 * @param {Robot}  robot                  Hubot Robot instance
 * @param {Object} [options]              Key/val options for config
 * @param {Object} [options.save]         Store records in hubot brain
 * @param {array} [options.events]        Event names to record
 * @param {array} [options.responseAtts]  Response keys or paths to record
 * @param {array} [options.instanceAtts]  Module instance keys or paths to record
 * @param {string} [key]                  Key name for this instance
 *
 * @example <caption>transcript to record room name when match emitted</caption>
 * let matchRecordRooms = new Transcript(robot, {
 *   responseAtts: ['message.room']
 *   events: ['match']
 * })
 * // does not start recording until calling one of the record methods, like:
 * matchRecordRooms.recordAll()
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
   * Record given event details in array, save to hubot brain if configured to.
   *
   * Events emitted by Playbook always include module instance as first param.
   *
   * This is only called internally on watched events after running `recordAll`,
   * `recordDialogue`, `recordScene` or `recordDirector`
   *
   * @param {string} event The event name
   * @param {*} args...    Args passed with the event, usually consists of:<br>
   *                       - Playbook module instance<br>
   *                       - Hubot response object<br>
   *                       - other additional (special context) arguments
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

    if (!_.isEmpty(args)) {
      if (event === 'send' && args[0].strings) record.strings = args[0].strings
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

  recordListener (context) {}

  /**
   * Record events emitted by a given dialogue and it's path/s.
   *
   * Whenever a path is added to a dialogue, event handlers are added on the
   * path for the configured events.
   *
   * @param {Dialogue} dialogue The Dialogue instance
  */
  recordDialogue (dialogue) {
    let dialogueEvents = _.intersection(this.config.events, ['end', 'send', 'timeout', 'path'])
    let pathEvents = _.intersection(this.config.events, ['match', 'catch', 'mismatch'])
    dialogueEvents.map((event) => {
      dialogue.on(event, (...args) => this.recordEvent(event, dialogue, ...args))
    })
    dialogue.on('path', (path) => {
      pathEvents.map((event) => {
        path.on(event, (...args) => this.recordEvent(event, path, ...args))
      })
    })
  }

  /**
   * Record events emitted by a given scene and any dialogue it enters, captures
   * configured events from scene and its created dialogues and paths.
   *
   * @param {Scene} scene The Scnee instance
  */
  recordScene (scene) {
    scene.on('enter', (res) => {
      if (_.includes(this.config.events, 'enter')) this.recordEvent('enter', scene, res)
      this.recordDialogue(res.dialogue)
    })
    scene.on('exit', (...args) => {
      if (_.includes(this.config.events, 'exit')) this.recordEvent('exit', scene, ...args)
    })
  }

  /**
   * Record allow/deny events emitted by a given director. Ignores configured
   * events because director has distinct events.
   *
   * @param {Director} director The Director instance
  */
  recordDirector (director) {
    director.on('allow', (...args) => this.recordEvent('allow', director, ...args))
    director.on('deny', (...args) => this.recordEvent('deny', director, ...args))
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
   * // returns array of recorded event objects
   *
   * transcript.findRecords({
   *   message: { user: { name: 'jon' } }
   * }, 'message.text')
   * // returns array of message text attribute from recroded events
  */
  findRecords (subsetMatch, returnPath) {
    let found = _.filter(this.records, subsetMatch)
    if (returnPath == null) return found
    let foundAtPath = found.map((record) => _(record).at(returnPath).head())
    _.remove(foundAtPath, _.isUndefined)
    return foundAtPath
  }

  /**
   * Alias for findRecords for just response match attributes with a given
   * instance key, useful for simple lookups of information provided by users
   * within a specific conversation.
   *
   * @param  {string}  instanceKey    Recorded instance key to lookup
   * @param  {string}  [userId]       Filter results by a user ID
   * @param  {integer} [captureGroup] Filter match by regex capture group subset
   * @return {array}                  Contains full match or just capture group
   *
   * @example <caption>find answers from a specific dialogue path</caption>
   * const transcript = new Transcript(robot)
   * robot.hear(/color/, (res) => {
   *   let favColor = new Dialogue(res, 'fav-color')
   *   transcript.recordDialogue(favColor)
   *   favColor.addPath([
   *     [ /my favorite color is (.*)/, 'duly noted' ]
   *   ])
   *   favColor.receive(res)
   * })
   * robot.respond(/what is my favorite color/, (res) => {
   *   let colorMatches = transcript.findKeyMatches('fav-color', 1)
   *   # ^ word we're looking for from capture group is at index: 1
   *   if (colorMatches.length) {
   *     res.reply(`I remember, it's ${ colorMatches.pop() }`)
   *   } else {
   *     res.reply("I don't know!?")
   *   }
   * })
   *
  */
  findKeyMatches (instanceKey, ...args) {
    let userId = (_.isString(args[0])) ? args.shift() : null
    let captureGroup = (_.isInteger(args[0])) ? args.shift() : null
    let subset = { instance: { key: instanceKey } }
    let path = 'response.match'
    if (userId != null) _.extend(subset, { message: { user: { id: userId } } })
    if (captureGroup != null) path += `[${captureGroup}]`
    return this.findRecords(subset, path)
  }

  /**
   * Alias for findRecords for just response match attributes with a given
   * listener ID, useful for lookups of matches from a specific listener.
   *
   * @param  {string}  listenerId     Listener ID match to lookup
   * @param  {string}  [userId]       Filter results by a user ID
   * @param  {integer} [captureGroup] Filter match by regex capture group subset
   * @return {array}                  Contains full match or just capture group
  */
  /*
  findIdMatches (listenerId, ...args) {
    let userId = (_.isString(args[0])) ? args.shift() : null
    let captureGroup = (_.isInteger(args[0])) ? args.shift() : null
    let subset = { listener: { options: { id: listenerId } } }
    let path = 'response.match'
    if (userId != null) subset.message = { user: { id: userId } }
    if (captureGroup != null) path += `[${captureGroup}]`
    return this.findRecords(subset, path)
  }
  */
}

module.exports = Transcript
