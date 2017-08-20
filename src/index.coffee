_ = require 'lodash'

{Dialogue, Scene, Director, Transcript, Improv} = require './modules'

###*
 * Playbook is a conversation branching library for Hubots, with many utilities
 * Modules are available as properties and their instances as collection items
 * Uses singleton pattern to make sure only one Playbook is created when used
 * in multiple script files loaded by the same Hubot
###
class PlaybookSingleton
  instance = null

  class PlaybookPrivate

    ###*
     * Initialise new Playbook
    ###
    constructor: -> @init()

    ###*
     * Init module collections and prototypes
    ###
    init: ->
      @dialogues = []
      @scenes = []
      @directors = []
      @transcripts = []
      @improv = null
      @Scene = Scene
      @Dialogue = Dialogue
      @Director = Director
      @Transcript = Transcript
      @Improv = Improv

    ###*
     * Attach Playbook to Hubot unless already done
     * @param  {Robot}    @robot Hubot instance
     * @return {Playbook}        Self for chaining
    ###
    use: (@robot) ->
      return @robot.playbook if @robot.playbook is @
      @robot.playbook = @
      @log = @robot.logger
      @log.info "Playbook using #{ @robot.name } bot"
      return @

    ###*
     * Create stand-alone dialogue (not within scene)
     * @param  {*} args - Dialogue constructor args
     * @return {Scene}      - New Scene instance
    ###
    dialogue: (args...) ->
      dialogue = new @Dialogue args...
      @dialogues.push dialogue
      return dialogue

    ###*
     * Create new Scene
     * @param  {*} args - Scene constructor args
     * @return {Scene}      - New Scene instance
    ###
    scene: (args...) ->
      scene = new @Scene @robot, args...
      @scenes.push scene
      return scene

    ###*
     * Create and enter Scene
     * @param  {Response} res     - Response object from entering participant
     * @param  {*}   [args]   - Both Scene and Dialogue constructor options
     * @return {Dialogue|Boolean} - Enter result, Dialogue or false if failed
    ###
    sceneEnter: (res, args...) ->
      scene = new @Scene @robot, args...
      dialogue = scene.enter res, args...
      @scenes.push scene
      return dialogue

    ###*
     * Create scene and setup listener to enter
     * @param  {String}   type     - Robot listener type: hear|respond
     * @param  {RegExp}   regex    - Match pattern
     * @param  {*}    args     - Scene constructor args
     * @param  {Function} callback - Callback to fire after entered
     * @return {Scene}             - New Scene instance
    ###
    sceneListen: (type, regex, args..., callback) ->
      scene = @scene args...
      scene.listen type, regex, callback
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
     * Create new Director
     * @param  {*} args - Constructor args
     * @return {Director}   - New Director instance
    ###
    director: (args...) ->
      director = new @Director @robot, args...
      @directors.push director
      return director

    ###*
     * Create a transcript with optional config to record events from modules
     * @param  {*}      args - Constructor args
     * @return {Transcript}      - The new transcript
    ###
    transcript: (args...) ->
      transcript = new @Transcript @robot, args...
      @transcripts.push transcript
      return transcript

    ###*
     * Create transcript and record a given module in one step
     * TODO: allow passing instance key instead of object, to find from arrays
     * @param  {*}  instance - A Playbook module (dialogue, scene, director)
     * @param  {*}      args - Constructor args
     * @return {Transcript}      - The new transcript
    ###
    transcribe: (instance, args...) ->
      transcript = @transcript args...
      transcript.recordDialogue instance if instance instanceof @Dialogue
      transcript.recordScene instance if instance instanceof @Scene
      transcript.recordDirector instance if instance instanceof @Director
      return transcript

    ###*
     * Initialise Improv singleton module, or update configuration if exists
     * Access methods via `Playbook.improv` property
     * @param {Object} [options] - Key/val options for config
     * @param {String} [key]     - Key name for this instance
     * @return {Improv} - Improv instance
    ###
    improvise: (args...) ->
      @improv = @Improv.get @robot, args...
      return @improv

    ###*
     * Exit all scenes, end all dialogues
     * TODO: detach listeners for scenes, directors, transcripts and improv
    ###
    shutdown: ->
      @log.info 'Playbook shutting down'
      _.invokeMap @scenes, 'exitAll'
      _.invokeMap @dialogues, 'end'
      return

    ###*
     * Shutdown and re-initialise instance (mostly for tests)
     * @return {Playbook} - The reset instance
    ###
    reset: ->
      @shutdown()
      @init()
      return @

  ###*
   * Static method either retrieves Playbook instance or creates new one
   * @return {Playbook}       - New or existing instance
  ###
  @get: -> instance ?= new PlaybookPrivate()

  ###*
   * Static method creates new Playbook instance
   * @return {Playbook}       - New instance
  ###
  @new: -> instance = new PlaybookPrivate()

module.exports =
  playbook: PlaybookSingleton.get()
  get: -> PlaybookSingleton.get()
  create: -> PlaybookSingleton.new()
  use: (robot) -> PlaybookSingleton.get().use robot
