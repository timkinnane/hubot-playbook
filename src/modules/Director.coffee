_ = require 'underscore'
{inspect} = require 'util'
{EventEmitter} = require 'events'

# Create middleware to authorise bot interactions, global or attached to scene
class Director extends EventEmitter
  constructor: (@robot, opts={}) ->
    @log = @robot.logger
