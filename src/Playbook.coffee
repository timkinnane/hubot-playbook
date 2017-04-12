_ = require 'underscore'
hooker = require 'hooker'

{Dialogue, Scene, Director, Helpers} = require './modules'

###*
 * Wrangler for modules provided by the Playbook library
 * Provides the robot object and easy access to variants of module constructors
 * @method constructor
 * @param  {object}    @robot The Hubot
###
class Playbook
  constructor: (@robot) ->
    @robot.playbook = @
    @log = @robot.logger
    @log.info 'Playbook starting up'
    @directors = []
    @scenes = []
    @dialogues = []

    # expose modules for individual usage
    @Director = Director
    @Dialogue = Dialogue
    @Scene = Scene

    # expose helper functions at top level
    @keygen = Helpers.keygen

    # shutdown playbook after robot shutdown called
    hooker.hook @robot, 'shutdown', post: => @shutdown()

  # create and return director
  director: (args...) ->
    @directors.push new @Director @robot, args...
    return _.last @directors

  # create and return scene
  scene: (args...) ->
    @scenes.push new @Scene @robot, args...
    return _.last @scenes

  # create and enter scene, returns dialogue, or false if failed to enter
  sceneEnter: (args...) ->
    type = args.shift() if typeof args[0] is 'string'
    @scenes.push new @Scene @robot, type
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
    @dialogues.push new @Dialogue args...
    return _.last @dialogues

  # exit all scenes and end all dialogues
  shutdown: ->
    @log.info 'Playbook shutting down'
    _.invoke @scenes, 'exitAll'
    _.invoke @dialogues, 'end'
    return

module.exports = Playbook
