_ = require 'lodash'

{Dialogue, Scene, Director, Transcript} = require './modules'

###*
 * Playbook is a conversation branching library for Hubots, with many utilities
 * Modules are available as properties and their instances as collection items
 * @param  {Robot}     robot - Hubot Robot instance
###
class Playbook
  constructor: (@robot) ->
    @log = @robot.logger
    @log.info 'Playbook starting up'
    @transcripts = []
    @directors = []
    @scenes = []
    @dialogues = []
    @Transcript = Transcript
    @Director = Director
    @Dialogue = Dialogue
    @Scene = Scene

  ###*
   * Create a transcript with optional config to record events from modules
   * @param  {Mixed}      args - Constructor args ./modules/Transcript.coffee
   * @return {Transcript}      - The new transcript
  ###
  transcript: (args...) ->
    transcript = new @Transcript @robot, args...
    @transcripts.push transcript
    return transcript

  ###*
   * Create transcript and record a given module in one step
   * @param  {Mixed}  instance - A Playbook module (dialogue, scene, director)
   * @param  {Mixed}      args - Constructor args ./modules/Transcript.coffee
   * @return {Transcript}      - The new transcript
  ###
  transcribe: (instance, args...) ->
    transcript = @transcript args...
    transcript.recordDialogue instance if instance instanceof @Dialogue
    transcript.recordScene instance if instance instanceof @Scene
    transcript.recordDirector instance if instance instanceof @Director
    return transcript

  ###*
   * Create new Director
   * @param  {Mixed} args - Constructor args ./modules/Director.coffee
   * @return {Director}   - New Director instance
  ###
  director: (args...) ->
    director = new @Director @robot, args...
    @directors.push director
    return director

  ###*
   * Create new Scene
   * @param  {Mixed} args - Scene constructor args ./modules/Director.coffee
   * @return {Scene}      - New Scene instance
  ###
  scene: (args...) ->
    scene = new @Scene @robot, args...
    @scenes.push scene
    return scene

  ###*
   * Create and enter Scene
   * @param  {String} [type]    - Scene type
   * @param  {Mixed} args       - Scene.enter args ./modules/Scene.coffee
   * @return {Dialogue|Boolean} - Enter result, Dialogue or false if failed
  ###
  sceneEnter: (args...) ->
    type = args.shift() if typeof args[0] is 'string'
    scene = new @Scene @robot, type
    dialogue = scene.enter args...
    @scenes.push scene
    return dialogue

  ###*
   * Create scene and setup listener to enter
   * @param  {String}   listenType - Robot listener type: hear|respond
   * @param  {RegExp}   regex      - Match pattern
   * @param  {Mixed}    args       - Scene constructor args
   * @param  {Function} callback   - Callback to fire after entered
   * @return {Scene}               - New Scene instance
  ###
  sceneListen: (listenType, regex, args..., callback) ->
    scene = @scene args...
    scene.listen listenType, regex, callback
    return scene

  ###*
   * Alias of sceneListen with hear as specified type
  ###
  sceneHear: (args...) ->
    return @sceneListen 'hear', args...

  ###*
   * Alias of sceneListen with respond as specified type
  ###
  sceneRespond: (args...) ->
    return @sceneListen 'respond', args...

  ###*
   * Create stand-alone dialogue (not within scene)
   * @param  {Mixed} args - Dialogue constructor args ./modules/Dialogue.coffee
   * @return {Scene}      - New Scene instance
  ###
  dialogue: (args...) ->
    dialogue = new @Dialogue args...
    @dialogues.push dialogue
    return dialogue

  ###*
   * Exit all scenes, end all dialogues
  ###
  shutdown: ->
    @log.info 'Playbook shutting down'
    _.invokeMap @scenes, 'exitAll'
    _.invokeMap @dialogues, 'end'
    return

module.exports = Playbook
