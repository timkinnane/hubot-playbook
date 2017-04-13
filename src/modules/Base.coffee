_ = require 'lodash'
slug = require 'slug'
{EventEmitter} = require 'events'

###*
 * Base class inherited by modules for consistent structure and common behaviour
 * Inherits EventEmitter so all modules can emit events.
 * @param  {String} name  - The class name (prefix for generating keys)
 * @param  {Robot} robot  - Robot instance
###
class Base extends EventEmitter
  defaults: {} # class (not instance) property - reference with Class::defaults

  constructor: (@name, @robot, options={}) ->
    @error 'Module requires a name' unless _.isString @name
    @error 'Module requires a robot object' unless _.isObject @robot
    @id = @keygen "#{ @name }_#{ @config.key or '' }" # e.g. module_key_1
    @log = @robot.logger
    @config = _.defaults options, @defaults

  ###*
   * Generic error handling, logs and emits event before throwing
   * @param  {String} [err] - Description of error (optional)
   * @param  {Error} [err]  - Error instance (optional)
   * @return null           - Throws, never returns
  ###
  error: (err) ->
    if _.isString err
      text = "#{ @id or 'constructor' }: #{ err }"
      err = new Error text
    @robot.emit 'error', err if @robot?
    throw err

  ###*
   * Get a unique ID including class name, sequenitally unless given key string
   * @param  {String} [key] - Input to be "slugified" into a safe key string
   * @return {String}       - Concatenated key from class type and generated ID
  ###
  keygen: (key) ->
    scope = if @id? then "#{@id}_#{key}" else key
    return _.uniqueId "#{ slug scope }_"

module.exports = Base
