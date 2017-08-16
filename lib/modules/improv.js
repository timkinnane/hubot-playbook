'use strict';Object.defineProperty(exports, "__esModule", { value: true });var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);
var _Base = require('./Base');var _Base2 = _interopRequireDefault(_Base);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

// http://amanvirk.me/singleton-classes-in-es6/
let instance = null;

/**
                      * Parse message templates with context from user attributes, pre-populated
                      * custom data (optionally persisted in brain) or from custom functions, e.g. to
                      * query conversation history via a Transcript instance.
                      *
                      * Improv will parse any strings containing javascript template expressions, but
                      * it is important NOT to use back-ticks when declaring the string, or they will
                      * be rendered immediately instead of at runtime with Improv's context object.
                      *
                      * The context object is applied as 'this' in the scope where the template is
                      * rendered, e.g. `"hello ${ this.user.name }"` will render with the value at
                      * the _user.name_ path in the context object, which should be the current user
                      * (unless its been overriden by configurable extensions).
                      *
                      * Improv uses singleton pattern, all templates are handled by one instance.
                      * If an instance exists and a new one is requested, new options will be applied
                      * to the original instance, which is returned by the constructor instead.
                      *
                      * @param {Robot} robot                  Hubot Robot instance
                      * @param {Object} [options]             Key/val options for config
                      * @param {boolean} [options.save]       Keep context collection in hubot brain
                      * @param {string} [options.fallback]    Fallback content replace any unknowns within messages
                      * @param {string} [options.replacement] Replace all messages containing unknowns, overrides fallback
                      * @param {Object} [options.app]         Data object with app context attributes to merge into tempaltes
                      * @param {array} [options.admins]       Array of usernames authorised to populate context data
                      * @param {string} [key]                 Key name for this instance
                      */
class Improv extends _Base2.default {
  constructor(robot, ...args) {
    if (!instance) {
      super('improv', robot, ...args);
      this.defaults({
        save: true,
        fallback: process.env.IMRPOV_FALLBACK || 'unknown',
        replace: process.env.IMRPOV_REPLACE || null,
        locale: process.env.IMRPOV_LOCALE || 'en',
        formats: {},
        data: {} });

      this.extensions = [];
      this.use(robot);
      instance = this;
    } else if (_lodash2.default.isObject(args[0])) {
      instance.config(args[0]);
      instance.use(robot);
    }
    return instance;
  }

  /**
     * Use a robot and get data from the brain. Separated from constructor for
     * testing with reset robots.
     *
     * @param  {Robot} robot The robot to use, usually existing from constructor
     * @return {Improv}      Self for chaining
    */
  use(robot) {
    if (!_lodash2.default.isEqual(robot, this.robot)) {
      this.robot = robot;
      if (!this.robot.brain.get('improv')) this.robot.brain.set('improv', {});
      this.robot.responseMiddleware((c, n, d) => this.middleware(c, n, d));
    }
    return this;
  }

  /**
     * Add extra functions to provide further context. They are called with the
     * current context whenever a template is rendered and should return extra
     * key/values to merge with context and/or override keys of existing data.
     *
     * @param  {Function} dataFunc Receives current context, to return more data
     * @return {Improv}            Self for chaining
     *
     * @example <caption>extend context with user transcript history</caption>
     *
     * let improv = new Improv(robot)
     * let transcript = new Transcript(robot)
     * improv.extend((data) => {
     *   // get array of match objects from history of user supplying their favorite color
     *   let colorMessageMatches = transcript.findIdMatches('fav-color', data.user.id)
     *   // if found, get the latest match and text from the capture group, add to context
     *   if (colorMessageMatches) data.user.favColor = colorMessageMatches[0].pop()
     *   return data
     * })
     *
     * @param  {Function} dataFunc - Receives merge data, to more return data
     * @return {Self} - The instance for chaining
    */
  extend(dataFunc) {
    if (_lodash2.default.isFunction(dataFunc)) this.extensions.push(dataFunc);
    return this;
  }

  /**
     * Provdies current known user and app data for merging with tempalte.
     *
     * Runs any extension functions, e.g. to merge data from other sources.
     *
     * @param  {Object} user User (usually from middleware context)
     * @return {Object}      App and user (from brain) data, with any extras
     *
     * @todo Allow tagging other user's data by merge with robot.brain.userForId
    */
  mergeData(user) {
    let dataSources = [this.config.data, { user }];
    if (this.config.save) dataSources.push(this.robot.brain.get('improv'));
    let data = _lodash2.default.defaultsDeep({}, ...dataSources);
    let merged = _lodash2.default.reduce(this.extensions, (merge, func) => {
      _lodash2.default.defaultsDeep(merge, func(merge));
    }, data);
    return merged;
  }

  /**
     * Merge templated messages with context data (replace unknown as configured).
     * Used internally after context data gathered and possibly extended.
     *
     * @param {array}  strings One or more strings being posted
     * @param {Object} context Template data, called as 'this' for interpolation
     * @return {array}         Strings populated with context values
     *
     * @todo use fallback/replace for unknowns
    */
  parse(strings, context) {
    return _lodash2.default.map(strings, string => {
      const template = new Function(`return \`${string}\``); // eslint-disable-line
      // ⬆ StandardJS error: The Function constructor is eval
      return template.call(context);
      // ⬇ alternate version, using eval also gives error - you can't win!
      // const template = (string) => eval(`\`${string}\``)
      // return template.call(context, string)
    });
  }

  /**
     * Middleware checks for template tags and parses if required.
     *
     * @param  {Object}   context - Passed through middleware stack, with res
     * @param  {Function} next    - Called when all middleware is complete
     * @param  {Function} done    - Initial (final) completion callback
    */
  middleware(context, next, done) {
    const hasTag = _lodash2.default.some(context.strings, str => str.match(/\${.*}/));
    if (hasTag) {
      const data = this.mergeData(context.response.message.user);
      context.strings = this.parse(context.strings, data);
    }
    return next(done);
  }

  // TODO: look through array of messages for unknowns
  prepare(strings) {}

  // TODO: ask configured admins to provide context for any unknowns
  warn(unknowns) {}

  // TODO: add data to context
  remember(key, content) {}

  // TODO: remove data from context
  forget(key) {}

  /**
                  * Shutdown and re-initialise instance (mostly for tests)
                  * @return {Self} - The reset instance
                 */
  reset() {
    this.init();
    return this;
  }

  /**
     * Reset the singleton, for tests to get a real new instance
     */
  destroy() {
    instance = null;
  }}exports.default =


Improv;module.exports = exports['default'];