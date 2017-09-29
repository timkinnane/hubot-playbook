'use strict'

const _ = require('lodash')
const Base = require('./base')

// init vars
let instance, context, extensions

/**
 * Improv parses message templates at runtime with context from user attributes,
 * pre-populated data and/or custom extensions.
 *
 * e.g. "hello ${ this.user.name }" will render with the value at the user.name
 * path in current context.
 *
 * Message strings containing expressions are automatically rendered by Improv
 * middleware and can be merged with data from any source, including a
 * Transcript search for instance.
 *
 * Note:
 *
 * - The context object is applied as 'this' in the scope where the template is
 * rendered, e.g. `this.user.name` is the value at _user.name_ path.
 * - *Don't* use back-ticks when declaring strings, or it will render
 * immediately.
 * - Improv uses a singleton pattern to parse templates from a central
 * middleware. It should be initialised with a robot via `.use`.
 * - Calling `.reset()` will clear everything (for testing).
 *
 * @param {Robot} robot Hubot Robot instance
 * @return {Improv}     New or prior existing (singleton) instance
 */
class Improv extends Base {
  constructor (robot) {
    super('improv', robot)
    if (!instance) {
      instance = this
      this.defaults({
        save: true,
        fallback: process.env.IMPROV_FALLBACK || 'unknown',
        replacement: process.env.IMPROV_REPLACEMENT || null
      })
    }
    return instance
  }
}

/**
 * Setup middleware and improv context collection in the brain.
 *
 * This is the main interface to get either a new or existing instance.
 * If the robot is new but an instance exists (e.g. in tests) then Improv will
 * attach the new robot but keep existing config and extensions.
 *
 * @param  {Robot} robot The robot to use, usually existing from constructor
 * @return {Improv}      The instance - really only accessed by tests
 * @todo Test persistant context save/load from brain with a data store.
 */
function use (robot) {
  let improv = new Improv(robot)
  let searchStack = (item) => _.isEqual(item.toString(), middleware.toString())
  if (improv.robot == null ||
  (_.findIndex(robot.middleware.response.stack, searchStack) < 0)) {
    if (!robot.brain.get('improv')) robot.brain.set('improv', {})
    robot.responseMiddleware(middleware)
    improv.robot = robot
  }
  return improv
}

/**
 * Configure the Improv instance
 *
 * @param {Object} [options]             Key/val options for config
 * @param {boolean} [options.save]       Keep context collection in hubot brain
 * @param {string} [options.fallback]    Fallback content replace any unknowns within messages
 * @param {string} [options.replacement] Replace all messages containing unknowns, overrides fallback
 * @param {Object} [options.app]         Data object with app context attributes to merge into tempaltes
 * @param {array} [options.admins]       Array of usernames authorised to populate context data
 * @return {Object}                        The module exports for chaining
 */
function configure (options = {}) {
  if (!instance) throw new Error('Improv must be used with robot before configuring')
  instance.configure(options)
  return this
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
 * improv.extend((context) => {
 *   context.user.favColor = 'always blue'
 *   return context
 * })
 * robot.send({ user: user }, 'I know your favorite color is ${ this.user.favColor }')
 * // ^ middleware will render template with the values and user in context
*/
function extend (dataFunc) {
  if (!instance) throw new Error('Improv must be used with robot before extended')
  if (_.isFunction(dataFunc)) {
    if (extensions == null) extensions = []
    extensions.push(dataFunc)
  }
  return this
}

/**
 * Provdies current context to messages merged with any data reutrn by added
 * extensions and a user object (if provideed).
 *
 * @param  {Object} [user] User (usually from middleware context)
 * @return {Object}        Context and user data, with any extensions merged
 *
 * @todo Allow tagging other user's data by merge with robot.brain.userForId
*/
function mergeData (user = {}) {
  if (!instance) throw new Error('Improv must be used with robot before using data')
  if (context == null) context = {}
  let dataSources = [context, {user}]
  if (instance.config.save) dataSources.push(instance.robot.brain.get('improv'))
  let data = _.defaultsDeep({}, ...dataSources)
  let merged = _.reduce(extensions, (merge, func) => {
    return _.defaultsDeep(merge, func(merge))
  }, data)
  return merged
}

/**
 * Merge templated messages with context data (replace unknown as configured).
 * Called by middleware after context data gathered and possibly extended.
 *
 * Pre-renders each expression individually to catch and replace any unknowns.
 * Failed expressions will be replaced with fallback unless a full replacement
 * is configured, to replace the entire string.
 *
 * @param {array}  strings One or more strings being posted
 * @param {Object} context Template data, reference as 'this' for interpolation
 * @return {array}         Strings populated with context values
*/
function parse (strings, data) {
  return _.map(strings, (string) => {
    let regex = new RegExp(/(?:\$\{\s?)(.*?)(?:\s?\})/)
    let match
    while ((match = regex.exec(string)) !== null) {
      try {
        let template = new Function(`return \`${match[0]}\``) // eslint-disable-line
        // ⬆ StandardJS error: The Function constructor is eval
        let rendered = template.call(data)
        string = string.replace(match[0], rendered)
      } catch (e) {
        instance.log.warning(`'${match[1]}' unknown in improv context for message: ${string}`)
        if (instance.config.replacement !== null) return instance.config.replacement
        else string = string.replace(match[0], instance.config.fallback)
      }
    }
    return string
  })
}

/**
 * Middleware checks for template tags and parses if required.
 *
 * @param  {Object}   context - Passed through middleware stack, with res
 * @param  {Function} next    - Called when all middleware is complete
 * @param  {Function} done    - Initial (final) completion callback
*/
function middleware (context, next, done) {
  let hasExpression = _.some(context.strings, str => str.match(/\${.*}/))
  if (hasExpression) {
    let data = mergeData(context.response.message.user)
    context.strings = parse(context.strings, data)
  }
  return next()
}

/**
 * @todo ask configured admins to provide context for any unknowns
 */
function warn (unknowns) {}

/**
 * Add data to context on the fly
 *
 * @param {array/string} path The path of the property to set
 * @param {*} value           The value to set
 * @return {Object}             The module exports for chaining
 *
 * @todo Save to brain on update if configured to save
 */
function remember (path, value) {
  if (context == null) context = {}
  _.set(context, path, value)
  return this
}

/**
 * Remove data from context on the fly
 *
 * @param {array/string} path The path of the property to unset
 * @return {Object}             The module exports for chaining
 *
 * @todo Clear from brain on update if configured to save
 */
function forget (path) {
  if (context == null) context = {}
  else _.unset(context, path)
  return this
}

/**
 * Wipte slate for tests to reinitialise without existing instance or context
 */
function reset () {
  instance = null
  extensions = null
  context = null
}

module.exports = {
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
  get instance () { return instance },
  get context () {
    if (context == null) context = {}
    return context
  },
  get extensions () {
    if (extensions == null) extensions = []
    return extensions
  },
  get config () { if (instance) return instance.config }
}
