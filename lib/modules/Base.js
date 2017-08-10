'use strict';Object.defineProperty(exports, "__esModule", { value: true });var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

/**
                                                                                                                                                                                                                                                         * Common structure and behaviour inherited by all Playbook modules
                                                                                                                                                                                                                                                         * Provides unique ID, error handling, event routing and accepts options and
                                                                                                                                                                                                                                                         * named key as final arguments (inherited config is merged with options)
                                                                                                                                                                                                                                                         * @param {string} name      The module/class name
                                                                                                                                                                                                                                                         * @param {Robot}  robot     Robot instance
                                                                                                                                                                                                                                                         * @param {Object} [options] Key/val options for config
                                                                                                                                                                                                                                                         * @param {string} [key]     Key name for this instance
                                                                                                                                                                                                                                                        */
class Base {
  constructor(name, robot, ...args) {
    this.name = name;
    this.robot = robot;
    if (!_lodash2.default.isString(this.name)) this.error('Module requires a name');
    if (!_lodash2.default.isObject(this.robot)) this.error('Module requires a robot object');

    this.config = {};
    if (_lodash2.default.isObject(args[0])) this.configure(args.shift());
    if (_lodash2.default.isString(args[0])) this.key = args.shift();
    this.log = this.robot.logger;
    this.id = _lodash2.default.uniqueId();
  }

  /**
     * Generic error handling, logs and emits event before throwing
     * @param {string} [err] Description of error (optional)
     * @param {Error} [err]  Error instance (optional)
    */
  error(err) {
    if (_lodash2.default.isString(err)) {
      const text = `${this.id || 'constructor'}: ${err}`;
      err = new Error(text);
    }
    if (this.robot != null) this.robot.emit('error', err);
    throw err;
  }

  /**
     * Merge options with defaults to produce configuration
     * @param  {Object} options Key/vals to merge with defaults, existing config
     * @return {Base}           Self for chaining
    */
  configure(options) {
    if (!_lodash2.default.isObject(options)) this.error('Non-object received for config');
    this.config = _lodash2.default.defaultsDeep({}, options, this.config);
    return this;
  }

  /**
     * Emit events using robot's event emmitter, allows listening from any module
     * Prepends instance's unique ID, so event listens can be implicitly targeted
     * @param {string} event Name of event
     * @param {...*} [args]  Arguments passed to event
    */
  emit(event, ...args) {
    this.robot.emit(event, this, ...args);
  }

  /**
     * Fire callback on robot events if event's ID arguement matches this instance
     * @param {string}   event    Name of event
     * @param {Function} callback Function to call
    */
  on(event, callback) {
    this.robot.on(event, (instance, ...args) => {
      if (instance === this) callback(instance, ...args);
    });
  }}exports.default =


Base;module.exports = exports['default'];
//# sourceMappingURL=base.js.map