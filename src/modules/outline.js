'use strict'

const _ = require('lodash')
const Base = require('./base')
require('../utils/string-to-regex')

/**
 * Outlines are a conversation modelling schema / handler, with collections of
 * attributes for setting up scenes, dialogues, paths and directors, for
 * interactions defined as "bits".
 *
 * Define a key and condition to execute each bit, either consecutively off a
 * prior bit, or with a listen attribute to become effectively a global entry
 * point to a scene.
 *
 * A subsequent bit can even lead back to it’s own parent or any other bit,
 * creating a mesh of possible conversational pathways.
 *
 * The setupScenes option is provided to disable (set to false) automatically
 * adding listeners for bits that enter scenes, in case there's a need to
 * manipulate the bits first, then call `.setupScenes()` when ready.
 *
 * @param {Object[]} bits                     Array of objects with attributes to setup bits
 * @param {string}   bits[].key               Key for scene and/or dialogue running the bit (required)
 * @param {array}    [bits[].send]            String/s to send when doing bit (minimum requirement)
 * @param {string}   [bits[].catch]           To send if response unmatched by listeners
 * @param {string}   [bits[].condition]       Converted to regex for listener to trigger bit
 * @param {string}   [bits[].listen]          Type of listener (hear/respond) for scene entry bit
 * @param {string}   [bits[].scope]           Scope type for scene (only used if it has a listen type)
 * @param {array}    [bits[].next]            Key/s (strings) for consequitive bits
 * @param {Object}   [bits[].options]         Key/val options for scene and/or dialogue config
 * @param {Object}   [options]                Key/val options for outline config
 * @param {boolean}  [options.setupScenes]    Optionally set up scene listeners on load (default true)
 * @param {string}   [key]                    Key name for this instance
 */
class Outline extends Base {
  constructor (robot, bits, ...args) {
    super('outline', robot, ...args)
    this.defaults({ setupScenes: true })
    if (!_.every(bits, 'key')) this.error('missing key for bit')
    this.bits = bits
    if (!_.isNil(this.bits) && this.config.setupScenes) this.setupScenes()
  }

  /**
   * Helper, finds a bit with a given key.
   * @param  {string} key Key name for required bit
   * @return {Object}     Bit attributes
   */
  getByKey (key) {
    let found = _.find(this.bits, [ 'key', key ])
    if (_.isNil(found)) this.error(`invalid key (${key}) requested`)
    return found
  }

  /**
   * Helper, converts a mixed type condition into a regex.
   *
   * Utility for loading regex properties from a file which cast them as strings
   * or simply convert a single word to a regular expression.
   *
   * @param  {*}      condition RegExp to check or string to ccnvert
   * @return {RegExp}           A valid expression for the given condition
   */
  parseCondition (condition) {
    if (_.isRegExp(condition)) return condition
    if (_.isString(condition)) {
      let regex = condition.toRegExp()
      if (_.isRegExp(regex)) return regex
    }
    this.error(`Condition (${condition}) can't be cast as RegExp`)
  }

  /**
   * Setup scene listeners for all "global" bits in the outline via Playbook.
   *
   * Calling through Playbook (if available) allows it to keep a reference of
   * all created scenes that may be interacted with via other modules, like
   * directors and transcripts.
   *
   * Only applicable to bits with a `listen` attribute (hear or respond).
   * Subsequent bits will play out within the same scene so their listen type is
   * irrelevant because all responses from an engaged audience will be routed
   * to the current dialogue.
   *
   * Bits only require a `.listen` and `.condition` property to setup a scene
   * listener and will use defaults if `.type` and `.options` are undefined.
   *
   * @return {Outline} Self, for chaining
   */
  setupScenes () {
    let sceneBits = _.filter(this.bits, 'listen')
    if (!_.every(sceneBits, 'condition')) this.error('missing condition for listener')
    if (_.isNil(this.robot.playbook)) this.error('cannot setup scenes without playbook using bot')

    sceneBits.map((bit) => this.robot.playbook.sceneListen(
      bit.listen,
      this.parseCondition(bit.condition),
      bit.options || {},
      bit.key,
      this.bitCallback.bind(this, bit)
    ))
    return this
  }

  /**
   * Configure a dialogue with options from the executing bit (may be null).
   *
   * Dialogue is already open from the scene being triggered and should have
   * bit property already added by its callback.
   *
   * This is unnecessary for the initial bit's callback, because it inherits
   * the bit options from the scene, but subsequent dialogue's options must be
   * overwritten for each executing bit.
   *
   * @param   {Response} res Hubot Response object
   * @returns {Dialogue}     The dialogue instance with bit config
   */
  setupDialogue (res) {
    res.dialogue.key = res.bit.key
    res.dialogue.configure(res.bit.options || {})
    return res.dialogue
  }

  /**
   * Callback for listener executing a bit. Called with 'this' bound to outline.
   *
   * Send messages and setup any following listeners for a bit.
   * May be on entering the scene or continuing from a prior bit.
   * Adds the bit as response property.
   *
   * The bit argument is provided from binding when setting up the listener,
   * in the context of the listener firing, it will only call with res argument.
   *
   * @param   {Object}   bit The bit being executed
   * @param   {Response} res Hubot Response object
   * @returns {Promise}      Resolves with addPath result (when sends completed)
   *                         or immediately if there's no following bits.
   */
  bitCallback (bit, res) {
    res.bit = bit
    let sends = _.isArray(bit.send) ? bit.send : [bit.send] // cast string as array
    this.setupDialogue(res).send(...sends)
    if (_.isArray(bit.next)) return this.setupPath(res)
    else return Promise.resolve()
  }

  /**
   * Add path, options and branches to dialogue (within listener callback).
   *
   * Response object must already be populated with bit and dialogue.
   *
   * Here the bit's catch property shorthand is converted to the path's
   * catchMessage config.
   *
   * @param   {Response} res Hubot Response object
   * @returns {Promise}      Resolves with addPath result (when sends completed)
   */
  setupPath (res) {
    let branches = res.bit.next.map((nextKey) => {
      let nextBit = this.getByKey(nextKey)
      let regex = this.parseCondition(nextBit.condition)
      let callback = this.bitCallback.bind(this, nextBit)
      return [regex, callback]
    })
    if (res.bit.catch) {
      if (_.isNil(res.bit.options)) res.bit.options = {}
      res.bit.options.catchMessage = res.bit.catch
    }
    return res.dialogue.addPath(branches, res.bit.options, res.bit.key)
  }
}

module.exports = Outline
