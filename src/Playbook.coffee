_ = require 'underscore'
Dialogue = require './modules/Dialogue'
Scene = require './modules/Scene'

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
  enterScene: (type, args...) ->
    @scenes.push new Scene @robot, type
    _.last(@scenes).enter args...

  dialogue: (args...) ->
    @dialogues.push new Dialogue args...
    _.last @dialogues

  shutdown: ->
    _.invoke @scenes, 'exitAll'
    _.invoke @dialogues, 'end'

module.exports = Playbook
