import _ from 'lodash'
import Base from './base'
import Path from './path'

/**
 * Dialogues control which paths are available to which users in context.
 *
 * They route messages to the right paths, manage timeouts, send replies and
 * fire callbacks for the branches that match user messages.
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
   * @return {Promise} From hubot async middleware (if supported)
   * @todo update tests that wait for observer to use promise instead
  */
  send (...strings) {
    let sent
    if (this.config.sendReplies) sent = this.res.reply(...strings)
    else sent = this.res.send(...strings)
    this.emit('send', this.res, ...strings)
    return sent
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
    if (this.countdown != null) { clearTimeout() }
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
   * Any new path added overwrites the previous.
   *
   * @param {string} [prompt]   To send on path setup (e.g. presenting options)
   * @param {array}  [branches] Array of args for each branch, each containing:<br>
   *                            - RegExp for listener<br>
   *                            - String to send and/or<br>
   *                            - Function to call on match
   * @param {Object} [options]  Key/val options for path
   * @param {string} [key]      Key name for this path
   * @return {Path}             New path instance
   * @todo when .send uses promise, return promise that resolves with this.path
   *
   * @example
   * let dlg = new Dialogue(res)
   * let path = dlg.addPath('Turn left or right?', [
   *   [ /left/, 'Ok, going left!' ]
   *   [ /right/, 'Ok, going right!' ]
   * ], 'which-way')
  */
  addPath (...args) {
    if (_.isString(args[0])) this.send(args.shift())
    this.path = new this.Path(this.robot, ...args)
    if (this.path.branches.length) this.startTimeout()
    return this.path
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
   * If matched, fire handler, restart timeout.
   *
   * if no additional paths or branches added (by handler), end dialogue.
   *
   * Overrides the original response with current one.
   *
   * @param {Response} res Hubot Response object
   * @todo Wrap handler in promise, don't end() until it resolves
   * @todo Test with handler using res.http/get to populate new path
  */
  receive (res) {
    this.res = res
    if (this.ended) return false // dialogue is over, don't process
    this.log.debug(`Dialogue received ${this.res.message.text}`)
    const branch = this.path.match(this.res)
    if ((branch != null) && this.res.match) {
      this.clearTimeout()
      this.emit('match', this.res)
      branch.handler(this.res, this)
    } else if (branch != null) {
      this.emit('catch', this.res)
      branch.handler(this.res, this)
    } else {
      this.emit('mismatch', this.res)
    }
    if (this.path.closed) this.end()
  }
}

export default Dialogue
