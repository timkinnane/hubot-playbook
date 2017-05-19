_ = require 'lodash'

###*
 * Common structure and behaviour inherited by all Playbook modules
 * Provides unique ID, error handling, event routing and accepts options and
 * named key as final arguments (inherited config is merged with options)
 * @param {String} name      - The module/class name
 * @param {Robot}  robot     - Robot instance
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Base
  constructor: (@name, @robot, args...) ->
    @error 'Module requires a name' unless _.isString @name
    @error 'Module requires a robot object' unless _.isObject @robot
    @config ?= {}
    @configure args.shift() if _.isObject args[0]
    @key = args.shift() if _.isString args[0]
    @log = @robot.logger
    @id = _.uniqueId()

  ###*
   * Generic error handling, logs and emits event before throwing
   * @param  {String} [err] - Description of error (optional)
   * @param  {Error} [err]  - Error instance (optional)
  ###
  error: (err) ->
    if _.isString err
      text = "#{ @id or 'constructor' }: #{ err }"
      err = new Error text
    @robot.emit 'error', err if @robot?
    throw err

  ###*
   * Merge options with defaults to produce configuration
   * @param  {Object} options - Key/vals to merge with defaults, existing config
   * @return {Self}           - for chaining
  ###
  configure: (options) ->
    @error "Non-object received for config" unless _.isObject options
    @config = _.defaultsDeep options, @config
    return @

  ###*
   * Emit events using robot's event emmitter, allows listening from any module
   * Prepends instance's unique ID, so event listens can be implicitly targeted
   * @param  {String} event   Name of event
   * @param  {Mixed} args...  Arguments passed to event
  ###
  emit: (event, args...) ->
    @robot.emit event, @, args...
    return

  ###*
   * Fire callback on robot events if event's ID arguement matches this instance
   * @param  {String}   event    Name of event
   * @param  {Function} callback Function to call
  ###
  on: (event, callback) ->
    @robot.on event, (instance, args...) =>
      callback instance, args... if instance is @
    return

module.exports = Base
