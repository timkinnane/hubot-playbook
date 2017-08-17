'use strict';Object.defineProperty(exports, "__esModule", { value: true });

var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);
var _Base = require('./Base');var _Base2 = _interopRequireDefault(_Base);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

// init vars
let instance, context, extensions;

/**
                                    * Parse message templates at runtime with context from user attributes,
                                    * pre-populated data (optionally persisted in brain) or from custom functions,
                                    * e.g. to query conversation history via a Transcript instance.
                                    *
                                    * Improv parses javascript template expressions, but *don't* use back-ticks
                                    * when declaring the string, or it will render immediately without context.
                                    *
                                    * Improv is initialised with a robot via `.use` and will throw otherwise.
                                    *
                                    * The context object is applied as 'this' in the scope where the template is
                                    * rendered, e.g. `"hello ${ this.user.name }"` will render with the value at
                                    * the _user.name_ path in the context object, which should be the current user
                                    * (unless its been overriden by configurable extensions).
                                    *
                                    * Improv uses a singleton pattern, so templates are passed by a single
                                    * middleware. Re-using after initial setup will replace the robot but existing
                                    * context will persist. Calling `.reset()` will clear everything (for testing).
                                    *
                                    * @param {Robot} robot                  Hubot Robot instance
                                    */
class Improv extends _Base2.default {
  constructor(robot) {
    if (!instance) {
      super('improv', robot);
      this.defaults({
        save: true,
        fallback: process.env.IMRPOV_FALLBACK || 'unknown',
        replace: process.env.IMRPOV_REPLACE || null });

      instance = this;
    }
    return instance;
  }}


/**
      * Use a robot and setup improv context collection in the brain.
      *
      * This is the main interface to get either a new or existing instance.
      * If the robot is new but an instance exists (e.g. in tests) then Improv will
      * attach the new robot but keep existing config and extensions.
      *
      * @param  {Robot} robot The robot to use, usually existing from constructor
      * @return {Improv}      The instance, for test access to base module properties
      * @todo Test persistant context save/load from brain with a data store.
      */
function use(robot) {
  let improv = new Improv(robot);
  if (!_lodash2.default.isEqual(improv.robot, robot)) {
    if (!robot.brain.get('improv')) robot.brain.set('improv', {});
    robot.responseMiddleware((c, n, d) => middleware(c, n, d));
    improv.robot = robot;
  }
  return instance;
}

/**
   * Configure the Improv instance (pass options to base configure method).
   *
   * @param {Object} [options]             Key/val options for config
   * @param {boolean} [options.save]       Keep context collection in hubot brain
   * @param {string} [options.fallback]    Fallback content replace any unknowns within messages
   * @param {string} [options.replacement] Replace all messages containing unknowns, overrides fallback
   * @param {Object} [options.app]         Data object with app context attributes to merge into tempaltes
   * @param {array} [options.admins]       Array of usernames authorised to populate context data
   * @return {this}                        The exported module for chaining
   */
function configure(options = {}) {
  if (!instance) throw new Error('Improv must be used with robot before configuring');
  instance.configure(options);
  return this;
}

/**
   * Add extra functions to provide further context. They are called with the
   * current context whenever a template is rendered and should return extra
   * key/values to merge with context and/or override keys of existing data.
   *
   * @param  {Function} dataFunc Receives current context, to return more data
   * @return {Improv}            The instance for chaining
   *
   * @example <caption>extend context with user transcript history</caption>
   *
   * improv.use(robot)
   * let transcript = new Transcript(robot)
   * improv.extend((context) => {
   *   let colorMessageMatches = transcript.findIdMatches('fav-color', context.user.id)
   *   // ^ array of match objects from history of user supplying their favorite color
   *   if (colorMessageMatches) context.user.favColor = colorMessageMatches[0].pop()
   *   // ^ get the latest match and text from the capture group, add to context
   *   return context
   * })
   * robot.send({ user: user }, 'I know your favorite color is ${ this.user.favColor }')
   * // ^ middleware will render template with the value in improv context
   *
   * @param  {Function} dataFunc Receives merge data, to more return data
   * @return {this}              The exported module for chaining
  */
function extend(dataFunc) {
  if (!instance) throw new Error('Improv must be used with robot before extended');
  if (_lodash2.default.isFunction(dataFunc)) {
    if (extensions == null) extensions = [];
    extensions.push(dataFunc);
  }
  return this;
}

/**
   * Provdies current context to templates merged with any data reutrn by added
   * extensions and a user object (if provideed).
   *
   * @param  {Object} [user] User (usually from middleware context)
   * @return {Object}        Context and user data, with any extensions merged
   *
   * @todo Allow tagging other user's data by merge with robot.brain.userForId
  */
function mergeData(user = {}) {
  if (!instance) throw new Error('Improv must be used with robot before using data');
  if (context == null) context = {};
  let dataSources = [context, { user }];
  if (instance.config.save) dataSources.push(instance.robot.brain.get('improv'));
  let data = _lodash2.default.defaultsDeep({}, ...dataSources);
  let merged = _lodash2.default.reduce(extensions, (merge, func) => {
    return _lodash2.default.defaultsDeep(merge, func(merge));
  }, data);
  return merged;
}

/**
   * Merge templated messages with context data (replace unknown as configured).
   * Used internally after context data gathered and possibly extended.
   *
   * Pre-renders each expression individually to catch and replace any unknowns.
   *
   * @param {array}  strings One or more strings being posted
   * @param {Object} context Template data, called as 'this' for interpolation
   * @return {array}         Strings populated with context values
   *
   * @todo use fallback/replace for unknowns
  */
function parse(strings, data) {
  return _lodash2.default.map(strings, string => {
    let regex = new RegExp(/(?:\$\{\s?)(.*?)(?:\s?\})/);
    let match;
    console.log(data);
    while ((match = regex.exec(string)) !== null) {
      try {
        let template = new Function(`return \`${match[0]}\``); // eslint-disable-line
        let rendered = template.call(data);
        // ⬆ StandardJS error: The Function constructor is eval
        // ⬇ alternate version, using eval also gives StandardJS error - can't win!
        // const template = (string) => eval(`\`${string}\``)
        // let rendered = template.call(context, string)
        console.log(rendered);
        string = string.replace(match[0], rendered);
      } catch (e) {
        instance.log.error(`'${match[1]}' unknown in improv context for message: ${string}`);
        string = string.replace(match[0], 'unknown');
      }
    }
    return string;
  });
}

/**
   * Middleware checks for template tags and parses if required.
   *
   * @param  {Object}   context - Passed through middleware stack, with res
   * @param  {Function} next    - Called when all middleware is complete
   * @param  {Function} done    - Initial (final) completion callback
  */
function middleware(context, next, done) {
  const hasTag = _lodash2.default.some(context.strings, str => str.match(/\${.*}/));
  if (hasTag) {
    const data = mergeData(context.response.message.user);
    context.strings = parse(context.strings, data);
  }
  return next(done);
}

/**
   * @todo ask configured admins to provide context for any unknowns
   */
function warn(unknowns) {}

/**
                            * Add data to context on the fly
                            *
                            * @param {array|string} path The path of the property to set
                            * @param {*} value           The value to set
                            * @return {this}             The exported module for chaining
                            *
                            * @todo Save to brain on update if configured
                            */
function remember(path, value) {
  if (context == null) context = {};
  _lodash2.default.set(context, path, value);
  return this;
}

/**
   * Remove data from context on the fly
   *
   * @param {array|string} path The path of the property to unset
   * @return {this}             The exported module for chaining
   *
   * @todo Clear from brain on update if configured
   */
function forget(path) {
  if (context == null) context = {};else
  _lodash2.default.unset(context, path);
  return this;
}

/**
   * Wipte slate for tests to reinitialise without existing instance or context
   */
function reset() {
  instance = null;
  extensions = null;
  context = null;
}exports.default =

{
  Improv: Improv,
  use: use,
  configure: configure,
  extend: extend,
  mergeData: mergeData,
  parse: parse,
  warn: warn,
  remember: remember,
  forget: forget,
  reset: reset,
  get instance() {return instance;},
  get context() {
    if (context == null) context = {};
    return context;
  },
  get extensions() {
    if (extensions == null) extensions = [];
    return extensions;
  },
  get config() {return instance.config;} };module.exports = exports['default'];