'use strict';Object.defineProperty(exports, "__esModule", { value: true });

var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);
var _base = require('./base');var _base2 = _interopRequireDefault(_base);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

/**
                                                                                                                                                                        * Paths and their child branches are the smallest and most essential node for
                                                                                                                                                                        * conversations. Instead of listening for all triggers at all times, paths
                                                                                                                                                                        * allow matching multiple choices in a tightly scoped context.
                                                                                                                                                                        *
                                                                                                                                                                        * A path usually contains one or more _branches_ to follow when matched.
                                                                                                                                                                        *
                                                                                                                                                                        * A path is _opened_ when branches added and _closed_ when a branch is
                                                                                                                                                                        * matched (unless more are added). Using brnach callbacks, the path can keep
                                                                                                                                                                        * laying new branches to remain open, until finally a branch is matched
                                                                                                                                                                        * without any new ones added.
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
                                                                                                                                                                        * @example <caption>with an array of text responses</caption>
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
class Path extends _base2.default {
  constructor(robot, ...args) {
    let branches = _lodash2.default.isArray(args[0]) ? args.shift() : false;
    super('path', robot, ...args);

    this.branches = [];
    this.closed = true;
    if (branches) {
      if (!_lodash2.default.isArray(branches)) this.error('Branches must be Array');
      if (!_lodash2.default.isArray(branches[0])) branches = [branches]; // cast 2D array
      for (let branch of branches) this.addBranch(...branch);
    }
  }

  /**
     * Add a branch (matching expression and handler) for optional dialogue input.
     *
     * On match, handler either fires callback, sends a message or both.
     *
     * @param {RegExp} regex        Matching pattern
     * @param {string} [message]    Message text for response on match
     * @param {Function} [callback] Function called when matched
     *
     * @example <caption>with regex, message and callback</caption>
     * path.addBranch(/hello/i, 'hello there', helloCallback)
    */
  addBranch(regex, ...args) {
    let callback, message;
    if (!_lodash2.default.isRegExp(regex)) this.error('Invalid RegExp for branch');
    if (_lodash2.default.isString(args[0])) message = args.shift();
    if (_lodash2.default.isFunction(args[0])) callback = args.shift();
    if (message == null && callback == null) this.error('Missing args for branch');
    this.branches.push({
      regex: regex,
      handler: res => {
        if (message != null) res.dialogue.send(message);
        if (callback != null) callback(res);
      } });

    this.closed = false; // path is open as long as branches are added
  }

  /**
     * Called when nothing matches, behaviour depends on config.
     * If neither is set, nothing happens.
     *
     * @return {Object} Contains .handler (function) or null if not configured
    */
  catch() {
    if (this.config.catchMessage == null && this.config.catchCallback == null) return;
    return {
      handler: res => {
        if (this.config.catchMessage != null) res.dialogue.send(this.config.catchMessage);
        if (this.config.catchCallback != null) this.config.catchCallback(res);
      } };

  }

  /**
     * Attempt to match an incoming response object.
     *
     * Overrides the response match (from dialogue listener) even if null match.
     *
     * Matching closes the path, but the handler may add branches, re-opening it.
     *
     * Without match, will attempt catch (which may also return null).
     *
     * @param  {Response} res     Hubot Response object
     * @return {Object|undefined} Matched branch with regex and handler
     *
     * @example
     * let choice = new Path(robot, [
     *   [ /door 1/, 'foo' ]
     *   [ /door 2/, 'bar', () => bar() ]
     *   [ /door 3/, () => baz() ]
     * ])
     * robot.hear(/door/, (res) => choice.match(res))
    */
  match(res) {
    const { text } = res.message;
    const branch = _lodash2.default.find(this.branches, function (branch) {
      res.match = text.match(branch.regex);
      return res.match; // truthy / falsey
    });
    if (branch != null) this.closed = true;
    return branch || this.catch();
  }}exports.default =


Path;module.exports = exports['default'];