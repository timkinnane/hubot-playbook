_ = require 'underscore'
Dialogue = require './modules/Dialogue'
Scene = require './modules/Scene'
Director = require './modules/Director'

# TODO: Refactor class and usage as singleton

# A container class for modules provided by the Playbook library
# For modules that require the robot as an argument, Playbook will pass it first
class Playbook
  constructor: (@robot) ->
    @log = @robot.logger
    @log.info 'Playbook starting up'
    @directors = []
    @scenes = []
    @dialogues = []

  # create and return director
  director: (args...) ->
    @directors.push new Director @robot, args...
    return _.last @directors

  # create and return scene
  scene: (type) ->
    @scenes.push new Scene @robot, type
    return _.last @scenes

  # create and enter scene, returns dialogue, or false if failed to enter
  sceneEnter: (args...) ->
    type = args.shift() if typeof args[0] is 'string'
    @scenes.push new Scene @robot, type
    dialogue = _.last @scenes
      .enter args...
    return dialogue

  # create scene and setup listener callback to enter
  # final param is another callback passing the dialogue and response on enter
  # returns the scene
  sceneListen: (listenType, regex, args..., callback) ->
    scene = @scene args...
    scene.listen listenType, regex, callback
    return scene

  # alias of sceneListen with hear as specified type
  sceneHear: (args...) ->
    return @sceneListen 'hear', args...

  # alias of sceneListen with respond as specified type
  sceneRespond: (args...) ->
    return @sceneListen 'respond', args...

  # create stand-alone dialogue (not within scene)
  dialogue: (args...) ->
    @dialogues.push new Dialogue args...
    return _.last @dialogues

  # exit all scenes and end all dialogues
  shutdown: ->
    @log.info 'Playbook shutting down'
    _.invoke @scenes, 'exitAll'
    _.invoke @dialogues, 'end'
    return

module.exports = Playbook

# TODO: Optional config for send middleware to throttle hearing consecutive res
# - display "thinking" elipses
