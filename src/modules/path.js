'use strict'

const _ = require('lodash')
const Base = require('./base')
require('../utils/string-to-regex')

/**
 * Paths are the smallest and most essential node for conversations. They allow
 * matching message text against multiple branches in a tightly scoped context.
 *
 * A path is open when branches are added and closed when a branch is matched.
 * While open, it can process incoming messages against the possible branches.
 *
 * A matched branch can respond to the user and lay more branches to keep the
 * path open, until finally a branch is matched without any new ones added.
 *
 * @param {Robot}  robot                   Hubot Robot instance
 * @param {array}  [branches]              Array of args for each branch, each containing:<br>
 *                                         - RegExp for listener<br>
 *                                         - String to send and/or<br>
 *                                         - Function to call on match
 * @param {Object} [options]               Key/val options for config
 * @param {Object} [options.catchMessage]  Message to send via catch handler
 * @param {Object} [options.catchCallback] Function to call within catch handler
 * @param {string} [key]                   Key name for this instance
 *
 * @example <caption>showing branch argument variations</caption>
 * let choice = new Path(robot, [
 *   [ /door 1/, 'foo' ]
 *   [ /door 2/, 'bar', () => bar() ]
 *   [ /door 3/, () => baz() ]
 * ])
 *
 * @example <caption>with message and callback options</caption>
 * let choice = new Path(robot, {
 *   catchMessage: 'sorry, nothing matched'
 *   catchCallback: () => noMatch()
 * })
*/
class Path extends Base {
  constructor (robot, ...args) {
    let branches = _.isArray(args[0]) ? args.shift() : false
    super('path', robot, ...args)

    this.branches = []
    this.closed = true
    if (branches) {
      if (!_.isArray(branches)) this.error('Branches must be Array')
      if (!_.isArray(branches[0])) branches = [branches] // cast 2D array
      for (let branch of branches) this.addBranch(...branch)
    }
  }

  /**
   * Add an optional dialogue branch.
   *
   * Each branch is assigned a handler to call on match, which can sends a
   * message and/or fire a given callback.
   *
   * Branch handlers are called by `.match`, if input matches a branch, which
   * then returns the matched handler's return value.
   *
   * @param {RegExp} regex           Matching pattern (accepts string, will cast as RegExp)
   * @param {string/array} [strings] Message text for response on match
   * @param {Function} [callback]    Function called when matched
   *
   * @example <caption>with regex, message and callback</caption>
   * path.addBranch(/hello/i, 'hello there', helloCallback)
  */
  addBranch (regex, ...args) {
    let callback, strings
    if (_.isString(regex) && _.isRegExp(regex.toRegExp())) regex = regex.toRegExp()
    if (!_.isRegExp(regex)) this.error(`Invalid RegExp for branch: ${regex}`)
    if (_.isString(args[0]) || _.isArray(args[0])) strings = args.shift()
    if (_.isFunction(args[0])) callback = args.shift()
    if ((strings == null) && (callback == null)) this.error('Missing args for branch')
    this.branches.push({
      regex: regex,
      handler: this.getHandler(strings, callback)
    })
    this.closed = false // path is open as long as branches are added
  }

  /**
   * Ready a function to call on a match or catch, sending stirngs and/or doing
   * a callback.
   *
   * Handlers return a promise that resolves with a merged object containing the
   * conext returned by send middleware if strings were sent, and the return
   * value of the callback if there was one.
   *
   * Either may return a promise so the result is wrapped to resolve both.
   *
   * @param  {string/array} strings Message text to send on match
   * @param  {Function} callback    Function to call on match
   * @return {Function}             The handler
   */
  getHandler (strings, callback) {
    return (res) => {
      let sent, called
      if (strings) {
        strings = _.castArray(strings)
        if (res.dialogue) sent = res.dialogue.send(...strings)
        else sent = res.reply(...strings)
      }
      if (callback) called = callback(res)
      return Promise.all([sent, called]).then(values => {
        return _.merge({}, values[0], values[1])
      })
    }
  }

  /**
   * Get handler for when nothing matches, if configured.
   *
   * If neither `catchMessage` or `catchCallback` is set, nothing happens.
   *
   * @return {Function} Handler (or undefined)
  */
  catchHandler () {
    if (this.config.catchMessage || this.config.catchCallback) {
      return this.getHandler(this.config.catchMessage, this.config.catchCallback)
    } else return false
  }

  /**
   * Attempt to match an incoming response object. Overrides the response match
   * (from the more general dialogue listener) even if null.
   *
   * Matching closes the path and fires the handler which may add branches,
   * re-opening it. Without a match, it will attempt to use a catch handler
   * (which may be null). The matched branch or catch handler method may return
   * a promise or not, the response is returned wrapped in a promise either way.
   *
   * @param  {Response} res Hubot Response object
   * @return {Promise}      Resolves with matched/catch branch handler result
   *
   * @example listener matching against possible branches
   * let choice = new Path(robot, [
   *   [ /door 1/, 'pies' ]
   *   [ /door 2/, 'lies' ]
   * ])
   * robot.hear(/door/, (res) => choice.match(res))
  */
  match (res) {
    let handler, handled
    const catchHandler = this.catchHandler()
    const matchedBranch = _.find(this.branches, function (branch) {
      res.match = res.message.text.match(branch.regex)
      return res.match // truthy / falsey
    })
    if (matchedBranch) handler = matchedBranch.handler
    if (handler) {
      this.closed = true
      this.emit('match', res)
      handled = handler(res)
    } else if (catchHandler) {
      this.emit('catch', res)
      handled = catchHandler(res)
    } else {
      this.emit('mismatch', res)
    }
    return Promise.resolve(handled)
  }
}

module.exports = Path
