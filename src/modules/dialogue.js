'use strict'

import _ from 'lodash'
import Base from './base'
import Path from './path'

/**
 * Dialogues control which paths are available and for how long. Passing
 * messages into a dialogue will match against the current path and route any
 * replies.
 *
 * Where paths are self-replicating steps, the dialogue persists along the
 * journey.
 *
 * @param {Response} res                  Hubot Response object
 * @param {Object} [options]              Key/val options for config
 * @param {boolean} [options.sendReplies] Toggle replying/sending (prefix with "@user")
 * @param {number} [options.timeout]      Allowed time to reply (in miliseconds) before cancelling listeners
 * @param {string} [options.timeoutText]  What to send when timeout reached, set null to not send
 * @param {string} [key]                  Key name for this instance
 *
 * @example <caption>listener sets up dialogue with user on match (10 second timeout)</caption>
 * robot.hear(/hello/, (res) => {
 *   let dlg = new Dialogue(res, { timeout: 10000 })
 *   // ...proceed to add paths
 * })
*/
class Dialogue extends Base {
  constructor (res, ...args) {
    super('dialogue', res.robot, ...args)
    this.defaults({
      sendReplies: false,
      timeout: parseInt(process.env.DIALOGUE_TIMEOUT || 30000),
      timeoutText: process.env.DIALOGUE_TIMEOUT_TEXT ||
        'Timed out! Please start again.'
    })
    res.dialogue = this
    this.res = res
    this.Path = Path
    this.path = null
    this.ended = false
  }

  /**
   * Shutdown and emit status (for scene to disengage participants).
   *
   * @return {boolean} Shutdown status, false if was already ended
  */
  end () {
    if (this.ended) return false
    if (this.countdown != null) this.clearTimeout()
    if (this.path != null) {
      this.log.debug(`Dialog ended ${this.path.closed ? '' : 'in'}complete`)
    } else {
      this.log.debug('Dialog ended before paths added')
    }
    this.emit('end', this.res)
    this.ended = true
    return this.ended
  }

  /**
   * Send or reply with message as configured (@user reply or send to room).
   *
   * @param {string} strings Message strings
   * @return {Promise} Resolves with result of send (respond middleware context)
  */
  send (...strings) {
    let sent
    if (this.config.sendReplies) sent = this.res.reply(...strings)
    else sent = this.res.send(...strings)
    return sent.then((result) => {
      this.emit('send', result.response, {
        strings: result.strings,
        method: result.method,
        received: this.res
      })
      return result
    })
  }

  /**
   * Default timeout method sends message, unless null or method overriden.
   *
   * If given a method it will call that or can be reassigned as a new function.
   *
   * @param  {Function} [override] - New function to call (optional)
  */
  onTimeout (override) {
    if (override != null) this.onTimeout = override
    else if (this.config.timeoutText != null) this.send(this.config.timeoutText)
  }

  /**
   * Stop countdown for matching dialogue branches.
  */
  clearTimeout () {
    clearTimeout(this.countdown)
    delete this.countdown
  }

  /**
   * Start (or restart) countdown for matching dialogue branches.
   *
   * Catches the onTimeout method because it can be overriden and may throw.
  */
  startTimeout () {
    if (this.countdown != null) clearTimeout()
    this.countdown = setTimeout(() => {
      this.emit('timeout', this.res)
      try {
        this.onTimeout()
      } catch (err) {
        this.error(err)
      }
      delete this.countdown
      return this.end()
    }, this.config.timeout)
    return this.countdown
  }

  /**
   * Add a dialogue path, with branches to follow and a prompt (optional).
   *
   * Any new path added overwrites the previous. If a path isn't given a key but
   * the parent dialogue has one, it will be given to the path.
   *
   * @param {string} [prompt]   To send on path setup (e.g. presenting options)
   * @param {array}  [branches] Array of args for each branch, each containing:<br>
   *                            - RegExp for listener<br>
   *                            - String to send and/or<br>
   *                            - Function to call on match
   * @param {Object} [options]  Key/val options for path
   * @param {string} [key]      Key name for this path
   * @return {Promise}          Resolves when sends complete or immediately
   *
   * @example
   * let dlg = new Dialogue(res)
   * let path = dlg.addPath('Turn left or right?', [
   *   [ /left/, 'Ok, going left!' ]
   *   [ /right/, 'Ok, going right!' ]
   * ], 'which-way')
  */
  addPath (...args) {
    let result
    if (_.isString(args[0])) result = this.send(args.shift())
    this.path = new this.Path(this.robot, ...args)
    if (!this.path.key && this.key) this.path.key = this.key
    this.emit('path', this.path)
    if (this.path.branches.length) this.startTimeout()
    return Promise.resolve(result).then(() => this.path)
  }

  /**
   * Add a branch to dialogue path, which is usually added first, but will be
   * created if not.
   *
   * @param {RegExp}   regex      Matching pattern
   * @param {string}   [message]  Message text for response on match
   * @param {Function} [callback] Function called when matched
  */
  addBranch (...args) {
    if (this.path == null) this.addPath()
    this.path.addBranch(...args)
    this.startTimeout()
  }

  /**
   * Process incoming message for match against path branches.
   *
   * If matched, restart timeout. If no additional paths or branches added (by
   * matching branch handler), end dialogue.
   *
   * Overrides any prior response with current one.
   *
   * @param {Response} res Hubot Response object
   * @return {Promise}     Resolves when matched/catch handler complete
   *
   * @todo Test with handler using res.http/get to populate new path
  */
  receive (res) {
    if (this.ended || this.path == null) return false // dialogue is over
    this.log.debug(`Dialogue received ${this.res.message.text}`)
    res.dialogue = this
    this.res = res
    let handlerResult = this.path.match(res)
    if (this.res.match) this.clearTimeout()
    if (this.path.closed) this.end()
    return handlerResult
  }
}

export default Dialogue
