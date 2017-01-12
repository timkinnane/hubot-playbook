Dialogue = require './modules/Dialogue'
Scene = require './modules/Scene'

# A container class for modules provided by the Playbook library
# For modules that require the robot as an argument, Playbook will pass it first
class Playbook
  constructor: (@robot) ->
  scene: (args...) -> new Scene @robot, args...
  dialogue: (args...) -> new Dialogue args...

module.exports = Playbook
