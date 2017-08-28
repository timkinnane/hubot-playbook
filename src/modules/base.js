'use strict'

import _ from 'lodash'

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
class Base {
  constructor (name, robot, ...args) {
    this.name = name
    this.robot = robot
    if (!_.isString(this.name)) this.error('Module requires a name')
    if (!_.isObject(this.robot)) this.error('Module requires a robot object')

    this.config = {}
    if (_.isObject(args[0])) this.configure(args.shift())
    if (_.isString(args[0])) this.key = args.shift()
    this.id = _.uniqueId(this.name)
  }

  /**
   * Getter allows robot to be replaced at runtime without losing route to log.
   *
   * @return {Object} The robot's log instance
   */
  get log () {
    return this.robot ? this.robot.logger : null
  }

  /**
   * Generic error handling, logs and emits event before throwing.
   *
   * @param {Error/string} err Error object or description of error
  */
  error (err) {
    if (_.isString(err)) {
      const text = `${this.id || 'constructor'}: ${err}`
      err = new Error(text)
    }
    if (this.robot != null) this.robot.emit('error', err)
    throw err
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
  configure (options) {
    if (!_.isObject(options)) this.error('Non-object received for config')
    this.config = _.defaults({}, options, this.config)
    return this
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
  defaults (settings) {
    if (!_.isObject(settings)) this.error('Non-object received for defaults')
    this.config = _.defaults({}, this.config, settings)
    return this
  }

  /**
   * Emit events using robot's event emmitter, allows listening from any module.
   *
   * Prepends the instance to event args, so listens can be implicitly targeted.
   *
   * @param {string} event Name of event
   * @param {...*} [args]  Arguments passed to event
  */
  emit (event, ...args) {
    this.robot.emit(event, this, ...args)
  }

  /**
   * Fire callback on robot events if event ID arguement matches this instance.
   *
   * @param {string}   event    Name of event
   * @param {Function} callback Function to call
  */
  on (event, callback) {
    this.robot.on(event, (instance, ...args) => {
      if (this === instance) callback(...args) // eslint-disable-line
    })
  }
}

export default Base
