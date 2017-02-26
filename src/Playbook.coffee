_ = require 'underscore'
Dialogue = require './modules/Dialogue'
Scene = require './modules/Scene'

# TODO: Refactor class and usage as singleton
# A container class for modules provided by the Playbook library
# For modules that require the robot as an argument, Playbook will pass it first
class Playbook
  constructor: (@robot) ->
    @scenes = []
    @dialogues = []

  # create and return scene
  scene: (type) ->
    @scenes.push new Scene @robot, type
    _.last @scenes

  # create and enter scene, returns dialogue
  enterScene: (args...) ->
    type = args.shift() if typeof args[0] is 'string'
    @scenes.push new Scene @robot, type
    _.last(@scenes).enter args...

  # create scene and setup listener callback to enter
  # final param is another callback passing the dialogue and response on enter
  # returns the scene
  promptScene: (listenType, regex, args..., callback) ->
    throw new Error "Invalid listenType" if listenType not in ['hear','respond']
    scene = @scene args...
    @robot[listenType] regex, (res) ->
      dialogue = scene.enter res
      callback.call dialogue, res # pass in dialogue as new this
    return scene

  func: (test) => null

  dialogue: (args...) ->
    @dialogues.push new Dialogue args...
    _.last @dialogues

  shutdown: ->
    _.invoke @scenes, 'exitAll'
    _.invoke @dialogues, 'end'

module.exports = Playbook
