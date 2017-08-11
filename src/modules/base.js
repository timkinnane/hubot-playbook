import _ from 'lodash'

/**
 * Provides common structure and behaviour inherited by all Playbook modules.
 *
 * Includes unique ID, error handling, event routing and accepts options and
 * named key as final arguments (inherited config is merged with options).
 *
 * The named key allows modules to be identified outside of functional logic,
 * for instance if they create listeners or logs or DB entries, they will attach
 * their key as a signature to ID which specific instance it was.
 *
 * @param {string} name      The module/class name
 * @param {Robot}  robot     Robot instance
 * @param {Object} [options] Key/val options for config
 * @param {string} [key]     Key name for instance
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
    this.log = this.robot.logger
    this.id = _.uniqueId(this.name)
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
    this.config = _.defaultsDeep({}, options, this.config)
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
    this.config = _.defaultsDeep({}, this.config, settings)
    return this
  }

  /**
   * Emit events using robot's event emmitter, allows listening from any module.
   *
   * Prepends instance's unique ID, so event listens can be implicitly targeted.
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
      if (instance === this) callback(instance, ...args)
    })
  }
}

export default Base
