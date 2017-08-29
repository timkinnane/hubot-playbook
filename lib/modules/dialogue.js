'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

var _lodash = require('lodash');

var _lodash2 = _interopRequireDefault(_lodash);

var _base = require('./base');

var _base2 = _interopRequireDefault(_base);

var _path2 = require('./path');

var _path3 = _interopRequireDefault(_path2);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

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
var Dialogue = function (_Base) {
  _inherits(Dialogue, _Base);

  function Dialogue(res) {
    var _ref;

    _classCallCheck(this, Dialogue);

    for (var _len = arguments.length, args = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
      args[_key - 1] = arguments[_key];
    }

    var _this = _possibleConstructorReturn(this, (_ref = Dialogue.__proto__ || Object.getPrototypeOf(Dialogue)).call.apply(_ref, [this, 'dialogue', res.robot].concat(args)));

    _this.defaults({
      sendReplies: false,
      timeout: parseInt(process.env.DIALOGUE_TIMEOUT || 30000),
      timeoutText: process.env.DIALOGUE_TIMEOUT_TEXT || 'Timed out! Please start again.'
    });
    res.dialogue = _this;
    _this.res = res;
    _this.Path = _path3.default;
    _this.path = null;
    _this.ended = false;
    return _this;
  }

  /**
   * Shutdown and emit status (for scene to disengage participants).
   *
   * @return {boolean} Shutdown status, false if was already ended
  */


  _createClass(Dialogue, [{
    key: 'end',
    value: function end() {
      if (this.ended) return false;
      if (this.countdown != null) this.clearTimeout();
      if (this.path != null) {
        this.log.debug('Dialog ended ' + (this.path.closed ? '' : 'in') + 'complete');
      } else {
        this.log.debug('Dialog ended before paths added');
      }
      this.emit('end', this.res);
      this.ended = true;
      return this.ended;
    }

    /**
     * Send or reply with message as configured (@user reply or send to room).
     *
     * @param {string} strings Message strings
     * @return {Promise} Resolves with result of send (respond middleware context)
    */

  }, {
    key: 'send',
    value: function send() {
      var _res,
          _res2,
          _this2 = this;

      var sent = void 0;
      if (this.config.sendReplies) sent = (_res = this.res).reply.apply(_res, arguments);else sent = (_res2 = this.res).send.apply(_res2, arguments);
      return sent.then(function (result) {
        _this2.emit('send', result.response, {
          strings: result.strings,
          method: result.method,
          received: _this2.res
        });
        return result;
      });
    }

    /**
     * Default timeout method sends message, unless null or method overriden.
     *
     * If given a method it will call that or can be reassigned as a new function.
     *
     * @param  {Function} [override] - New function to call (optional)
    */

  }, {
    key: 'onTimeout',
    value: function onTimeout(override) {
      if (override != null) this.onTimeout = override;else if (this.config.timeoutText != null) this.send(this.config.timeoutText);
    }

    /**
     * Stop countdown for matching dialogue branches.
    */

  }, {
    key: 'clearTimeout',
    value: function (_clearTimeout) {
      function clearTimeout() {
        return _clearTimeout.apply(this, arguments);
      }

      clearTimeout.toString = function () {
        return _clearTimeout.toString();
      };

      return clearTimeout;
    }(function () {
      clearTimeout(this.countdown);
      delete this.countdown;
    })

    /**
     * Start (or restart) countdown for matching dialogue branches.
     *
     * Catches the onTimeout method because it can be overriden and may throw.
    */

  }, {
    key: 'startTimeout',
    value: function startTimeout() {
      var _this3 = this;

      if (this.countdown != null) clearTimeout();
      this.countdown = setTimeout(function () {
        _this3.emit('timeout', _this3.res);
        try {
          _this3.onTimeout();
        } catch (err) {
          _this3.error(err);
        }
        delete _this3.countdown;
        return _this3.end();
      }, this.config.timeout);
      return this.countdown;
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

  }, {
    key: 'addPath',
    value: function addPath() {
      var _this4 = this;

      var result = void 0;

      for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
        args[_key2] = arguments[_key2];
      }

      if (_lodash2.default.isString(args[0])) result = this.send(args.shift());
      this.path = new (Function.prototype.bind.apply(this.Path, [null].concat([this.robot], args)))();
      if (!this.path.key && this.key) this.path.key = this.key;
      this.emit('path', this.path);
      if (this.path.branches.length) this.startTimeout();
      return Promise.resolve(result).then(function () {
        return _this4.path;
      });
    }

    /**
     * Add a branch to dialogue path, which is usually added first, but will be
     * created if not.
     *
     * @param {RegExp}   regex      Matching pattern
     * @param {string}   [message]  Message text for response on match
     * @param {Function} [callback] Function called when matched
    */

  }, {
    key: 'addBranch',
    value: function addBranch() {
      var _path;

      if (this.path == null) this.addPath();
      (_path = this.path).addBranch.apply(_path, arguments);
      this.startTimeout();
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

  }, {
    key: 'receive',
    value: function receive(res) {
      if (this.ended || this.path == null) return false; // dialogue is over
      this.log.debug('Dialogue received ' + this.res.message.text);
      res.dialogue = this;
      this.res = res;
      var handlerResult = this.path.match(res);
      if (this.res.match) this.clearTimeout();
      if (this.path.closed) this.end();
      return handlerResult;
    }
  }]);

  return Dialogue;
}(_base2.default);

exports.default = Dialogue;
module.exports = exports['default'];
//# sourceMappingURL=dialogue.js.map