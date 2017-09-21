'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

var _lodash = require('lodash');

var _lodash2 = _interopRequireDefault(_lodash);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

/**
 * Base is the parent class of every Playbook module, providing consistent
 * structure and behaviour.
 *
 * Every module built on Base can emit events, handle errors and call methods
 * through the bot.
 *
 * Helpers are provided to accept options and merge with class defaults to
 * configure the instance.
 *
 * All instances get a unique ID and can be given a named key so any interaction
 * or event can be queried and recorded against its source.
 *
 * @param {string} name      The module/class name
 * @param {Robot}  robot     Robot instance
 * @param {Object} [options] Key/val options for config
 * @param {string} [key]     Key name for instance (provided to events)
 *
 * @example
 * class RadModule extends Base {
 *   constructor (robot, args...) {
 *     super('rad', robot, args...)
 *   }
 * }
 * radOne = new RadModule(robot, { radness: 'high' })
 * radOne.id // == 'rad_1'
 * radOne.config.radness // == 'high'
*/
var Base = function () {
  function Base(name, robot) {
    _classCallCheck(this, Base);

    this.name = name;
    this.robot = robot;
    if (!_lodash2.default.isString(this.name)) this.error('Module requires a name');
    if (!_lodash2.default.isObject(this.robot)) this.error('Module requires a robot object');

    this.config = {};

    for (var _len = arguments.length, args = Array(_len > 2 ? _len - 2 : 0), _key = 2; _key < _len; _key++) {
      args[_key - 2] = arguments[_key];
    }

    if (_lodash2.default.isObject(args[0])) this.configure(args.shift());
    if (_lodash2.default.isString(args[0])) this.key = args.shift();
    this.id = _lodash2.default.uniqueId(this.name);
  }

  /**
   * Getter allows robot to be replaced at runtime without losing route to log.
   *
   * @return {Object} The robot's log instance
   */


  _createClass(Base, [{
    key: 'appendLogDetails',


    /**
     * Append the base instance details to any log it generates
     *
     * @param  {string} text The original log message
     * @return {string}      Log message with details appended
     */
    value: function appendLogDetails(text) {
      var details = 'id: ' + this.id;
      if (this.key !== undefined) details += ', key: ' + this.key;
      return text + ' (' + details + ')';
    }

    /**
     * Generic error handling, logs and emits event before throwing.
     *
     * @param {Error/string} err Error object or description of error
    */

  }, {
    key: 'error',
    value: function error(err) {
      if (_lodash2.default.isString(err)) {
        var text = (this.id || 'constructor') + ': ' + err;
        if (this.key !== undefined) text += ' (key: ' + this.key + ')';
        err = new Error(text);
      }
      if (this.robot != null) this.robot.emit('error', err);
      throw err;
    }

    /**
     * Merge-in passed options, override any that exist in config.
     *
     * @param  {Object} options Key/vals to merge with existing config
     * @return {Base}           Self for chaining
     *
     * @example
     * radOne.configure({ radness: 'overload' }) // overwrites initial config
    */

  }, {
    key: 'configure',
    value: function configure(options) {
      if (!_lodash2.default.isObject(options)) this.error('Non-object received for config');
      this.config = _lodash2.default.defaults({}, options, this.config);
      return this;
    }

    /**
     * Fill any missing settings without overriding any existing in config.
     *
     * @param  {Object} settings Key/vals to use as config fallbacks
     * @return {Base}            Self for chaining
     *
     * @example
     * radOne.defaults({ radness: 'meh' }) // applies unless configured otherwise
     */

  }, {
    key: 'defaults',
    value: function defaults(settings) {
      if (!_lodash2.default.isObject(settings)) this.error('Non-object received for defaults');
      this.config = _lodash2.default.defaults({}, this.config, settings);
      return this;
    }

    /**
     * Emit events using robot's event emmitter, allows listening from any module.
     *
     * Prepends the instance to event args, so listens can be implicitly targeted.
     *
     * @param {string} event Name of event
     * @param {...*} [args]  Arguments passed to event
    */

  }, {
    key: 'emit',
    value: function emit(event) {
      var _robot;

      for (var _len2 = arguments.length, args = Array(_len2 > 1 ? _len2 - 1 : 0), _key2 = 1; _key2 < _len2; _key2++) {
        args[_key2 - 1] = arguments[_key2];
      }

      (_robot = this.robot).emit.apply(_robot, [event, this].concat(args));
    }

    /**
     * Fire callback on robot events if event ID arguement matches this instance.
     *
     * @param {string}   event    Name of event
     * @param {Function} callback Function to call
    */

  }, {
    key: 'on',
    value: function on(event, callback) {
      var _this = this;

      this.robot.on(event, function (instance) {
        for (var _len3 = arguments.length, args = Array(_len3 > 1 ? _len3 - 1 : 0), _key3 = 1; _key3 < _len3; _key3++) {
          args[_key3 - 1] = arguments[_key3];
        }

        if (_this === instance) callback.apply(undefined, args); // eslint-disable-line
      });
    }
  }, {
    key: 'log',
    get: function get() {
      var _this2 = this;

      if (!this.robot) return null;
      return {
        info: function info(text) {
          return _this2.robot.logger.info(_this2.appendLogDetails(text));
        },
        debug: function debug(text) {
          return _this2.robot.logger.debug(_this2.appendLogDetails(text));
        },
        warning: function warning(text) {
          return _this2.robot.logger.warning(_this2.appendLogDetails(text));
        },
        error: function error(text) {
          return _this2.robot.logger.error(_this2.appendLogDetails(text));
        }
      };
    }
  }]);

  return Base;
}();

exports.default = Base;
module.exports = exports['default'];
//# sourceMappingURL=base.js.map