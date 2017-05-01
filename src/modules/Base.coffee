_ = require 'lodash'

###*
 * Base class inherited by modules for consistent structure and common behaviour
 * Inherits EventEmitter so all modules can emit events.
 * @param  {String} name  - The module/class name
 * @param  {Robot} robot  - Robot instance
###
class Base
  constructor: (@name, @robot, options={}) ->
    @error 'Module requires a name' unless _.isString @name
    @error 'Module requires a robot object' unless _.isObject @robot
    @log = @robot.logger
    @config = _.defaults options, @defaults
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
   * Emit events using robot's event emmitter, allows listening from any module
   * Prepends instance's unique ID, so event listens can be implicitly targeted
   * @param  {String} event   Name of event
   * @param  {Mixed} args...  Arguments passed to event
  ###
  emit: (event, args...) ->
    @robot.emit event, @id, args...
    return

  ###*
   * Fire callback on robot events if event's ID arguement matches this instance
   * @param  {String}   event    Name of event
   * @param  {Function} callback Function to call
  ###
  on: (event, callback) ->
    @robot.on event, (id, args...) => callback args... if id is @id
    return

module.exports = Base
