import _ from 'lodash'

/**
 * Common structure and behaviour inherited by all Playbook modules.
 *
 * Provides unique ID, error handling, event routing and accepts options and
 * named key as final arguments (inherited config is merged with options).
 *
 * @param {string} name      The module/class name
 * @param {Robot}  robot     Robot instance
 * @param {Object} [options] Key/val options for config
 * @param {string} [key]     Key name for this instance
 *
 * @example
 *  class RadModule extends Base {
 *    constructor (robot, args...) {
 *      super('rad', robot, args...)
 *    }
 *  }
 *  radInstance = new RadModule(robot, { radness: 'high' })
 *  radInstance.id // == 'rad_1'
 *  radInstance.configure({ radness: 'overload' }) // overwrites initial config
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
   * Merge options with defaults to produce configuration.
   *
   * @param  {Object} options Key/vals to merge with defaults, existing config
   * @return {Base}           Self for chaining
  */
  configure (options) {
    if (!_.isObject(options)) this.error('Non-object received for config')
    this.config = _.defaultsDeep({}, options, this.config)
    return this
  }

  /**
   * Emit events using robot's event emmitter, allows listening from any module.
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
