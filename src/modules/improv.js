'use strict'

const _ = require('lodash')
const Base = require('./base')
const captureExpression = new RegExp(/(?:\$\{\s?)(.*?)(?:\s?\})/g)

// init vars
let instance, data, extensions
reset()

/**
 * Improv parses message templates at runtime with data from user attributes,
 * pre-populated data and/or custom extensions.
 *
 * e.g. "hello ${ this.user.name }" will render with the value at the user.name
 * path in current data.
 *
 * Message strings containing expressions are automatically rendered by Improv
 * middleware and can be merged with data from any source, including a
 * Transcript search for instance.
 *
 * Note:
 *
 * - The data object is applied as 'this' in the scope where the template is
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
 * Setup middleware and improv data collection in the brain.
 *
 * This is the main interface to get either a new or existing instance.
 * If the robot is new but an instance exists (e.g. in tests) then Improv will
 * attach the new robot but keep existing config and extensions.
 *
 * @param  {Robot} robot The robot to use, usually existing from constructor
 * @return {Improv}      The instance - really only accessed by tests
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
 * @param {boolean} [options.save]       Keep data collection in hubot brain
 * @param {string} [options.fallback]    Fallback content replace any unknowns within messages
 * @param {string} [options.replacement] Replace all messages containing unknowns, overrides fallback
 * @param {array} [options.admins]       Array of usernames authorised to populate data
 * @return {Object}                      The module exports for chaining
 */
function configure (options = {}) {
  if (!instance) throw new Error('Improv must be used with robot before configuring')
  instance.configure(options)
  return this
}

/**
 * Add function to extend current data when rendering a template. Should return
 * key/values to merge and/or override keys of existing data.
 *
 * If given a path argument, the extension function will only be called when the
 * template string being rendered contains that path. This can prevent slow or
 * expensive requests from running when their data isn't required.
 *
 * Extensions can set properties within current data model or return a new
 * object, the keys and values will be deep merged so either will work.
 *
 * @param  {Function} dataFunc   Receives current data, to return more
 * @param  {string}   [dataPath] Scope for running the extension (optional)
 * @return {Improv}            The instance for chaining
 *
 * @example <caption>extend data with user transcript history</caption>
 *
 * improv.use(robot)
 * improv.extend((data) => {
 *   data.user.favColor = 'always blue'
 *   return data
 * }, 'user.favColor')
 * robot.send({ user: user }, 'I know your favorite color is ${ this.user.favColor }')
 * // ^ middleware will render template with the values and user in data
 * // ^ by providing the path, it will only be run when specifically required
*/
function extend (dataFunc, dataPath) {
  if (!instance) throw new Error('Improv must be used with robot before extended')
  if (_.isFunction(dataFunc)) extensions.push({ function: dataFunc, path: dataPath })
  return this
}

/**
 * Search an array of strings for template expressions with `this.` data path.
 *
 * @param  {array} strings Strings to search (usually from middleware)
 * @return {array}         Path matches objects\n
 *                         - [0]: expression including braces, e.g. `${ ... }`
 *                         - [1]: the path, e.g. this.path.to.data
 *                         - index: index of expression in string
 *                         - input: string containing the matched path
 */
function matchPaths (strings) {
  let match
  let paths = []
  for (let string of strings) {
    while ((match = captureExpression.exec(string)) !== null) {
      if (match[1].indexOf('this.' === 0)) paths.push(match)
    }
  }
  return paths
}

/**
 * Provdies current data to messages merged with response context any extra data
 * returned by added extensions.
 *
 * @param  {Object} context Data provided at runtime to merge with improv data (usually from middleware)
 * @param  {array}  [paths] Paths required, to filter out unnecessary extensions
 * @return {Object}         Data, middleware context and any extensions merged
*/
function mergeData (context, paths) {
  if (!instance) throw new Error('Improv must be used with robot before using data')

  // start with known data, given context and saved data (optional)
  let dataSources = [data, context]
  if (instance.config.save) dataSources.push(instance.robot.brain.get('improv'))

  // add user object to data root for shorter expressions
  let user = _(context).at('response.message.user').head()
  if (user) dataSources.push({user})

  // assign values from all sources and extensions (if any)
  let merged = _.defaultsDeep({}, ...dataSources)
  if (extensions.length === 0) return merged

  // provide existing data to extensions, if path requires it
  return extensions.reduce((merged, extension) => {
    let extensionRequired = (extension.path !== undefined)
      ? _.some(paths, (path) => extension.path.indexOf(path) !== -1)
      : true
    if (extension.path === undefined || extensionRequired) {
      return _.defaultsDeep(merged, extension.function(merged))
    } else {
      return merged
    }
  }, merged)
}

/**
 * Replace expressions in sent string if they match the format of a data at a
 * path bound to 'this', with the data at that path after collecting from all
 * sources.
 *
 * @param {object} context          Context object (usually from middleware)
 * @param {array}  context.strings  One or more strings being posted
 * @param {object} context.response Response object being replied to
 *
 * @return {array}         Strings populated with context values
*/
function parse (context) {
  if (context.strings === undefined) {
    throw new Error('Improv called without strings property in context argument')
  }

  // find path expressions in strings (may be none)
  let pathmatches = matchPaths(context.strings)
  if (pathmatches.length === 0) return context.strings

  // get all data for required paths then render strings containing each path
  let merged = mergeData(context, pathmatches.map((match) => match[1]))
  return context.strings.map((string) => {
    for (let match of _.filter(pathmatches, (m) => (m.input === string))) {
      if (string.indexOf(match[1])) string = render(string, match, merged)
    }
    return string
  })
}

/**
 * Convert string containing expression to an interpolation template and call
 * with supplied data bound to 'this'.
 *
 * Pre-renders expressions to catch and replace any unknowns. Failed expressions
 * will be replaced with fallback unless a full replacement is configured, to
 * replace the entire string.
 *
 * @param  {string} string   The string to replace expressions within
 * @param  {object} match    RegExp result where string contained an expression
 * @param  {object} callData Data to become 'this' when rendering expressions
 * @return {string}          The result of rendering match input with given data
 */
function render (string, match, callData) {
  try {
    let template = new Function(`return \`${match[0]}\``) // eslint-disable-line
    // ⬆ StandardJS error: The Function constructor is eval
    let rendered = template.call(callData)
    string = string.replace(match[0], rendered)
  } catch (e) {
    instance.log.warning(`'${match[1]}' unknown in improv context for message: ${string}`)
    if (instance.config.replacement !== null) return instance.config.replacement
    else string = string.replace(match[0], instance.config.fallback)
  }
  return string
}

/**
 * Middleware parses template expressions, replacing with data if required.
 *
 * @param  {Object}   context - Passed through middleware stack, with res
 * @param  {Function} next    - Called when all middleware is complete
 * @param  {Function} done    - Initial (final) completion callback
*/
function middleware (context, next, done) {
  context.strings = parse(context)
  return next()
}

function warn (unknowns) {}

/**
 * Add data to context on the fly
 *
 * @param {array/string} path The path of the property to set
 * @param {*} value           The value to set
 * @return {Object}             The module exports for chaining
 */
function remember (path, value) {
  _.set(data, path, value)
  return this
}

/**
 * Remove data from data on the fly
 *
 * @param {array/string} path The path of the property to unset
 * @return {Object}             The module exports for chaining
 */
function forget (path) {
  _.unset(data, path)
  return this
}

/**
 * Wipte slate for tests to reinitialise without existing instance or context
 */
function reset () {
  instance = null
  extensions = []
  data = {}
}

module.exports = {
  Improv,
  use,
  configure,
  extend,
  mergeData,
  parse,
  render,
  warn,
  remember,
  forget,
  reset,
  get instance () { return instance },
  get data () { return data },
  set data (props) { Object.assign(data, props) },
  get extensions () { return extensions }
}
