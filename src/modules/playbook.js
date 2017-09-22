const _ = require('lodash')
const Dialogue = require('./dialogue')
const Scene = require('./scene')
const Director = require('./director')
const Transcript = require('./transcript')
const Outline = require('./outline')
const improv = require('./improv')

let instance

/**
 * Playbook brings conversational context and branching to Hubot.
 *
 * Modules are available as properties and their instances as collection items.
 *
 * Uses singleton pattern to make sure only one Playbook is created when used
 * in multiple script files loaded by the same Hubot.
*/

class Playbook {
  constructor () {
    if (!instance) {
      this.dialogues = []
      this.scenes = []
      this.directors = []
      this.transcripts = []
      this.outlines = []
      this.Scene = Scene
      this.Dialogue = Dialogue
      this.Director = Director
      this.Transcript = Transcript
      this.Outline = Outline
      this.improv = improv
      instance = this
    }
    return instance
  }

  /**
   * Attach Playbook to robot unless already done.
   *
   * @param  {Robot}    robot       Hubot instance
   * @param  {boolean}  [improvise] Enable/disable improv module and middleware (default true)
   * @return {Playbook}             Self for chaining
  */
  use (robot, improvise = true) {
    this.robot = robot
    if (this.robot.playbook === this) return this.robot.playbook
    this.robot.playbook = this
    this.log = this.robot.logger
    this.log.debug(`Playbook using ${this.robot.name} bot`)
    if (improvise) this.improvise()
    return this
  }

  /**
   * Create stand-alone dialogue (not within scene).
   *
   * @param {Response} res Hubot Response object
   * @param  {*} [args]    Optional other Dialogue constructor args
   * @return {Dialogue}    New Dialogue instance
  */
  dialogue (res, ...args) {
    const dialogue = new this.Dialogue(res, ...args)
    this.dialogues.push(dialogue)
    return dialogue
  }

  /**
   * Create new Scene.
   *
   * @param  {*} [args] Optional Scene constructor args
   * @return {Scene}    New Scene instance
  */
  scene (...args) {
    const scene = new this.Scene(this.robot, ...args)
    this.scenes.push(scene)
    return scene
  }

  /**
   * Create and enter Scene.
   *
   * @param  {Response} res    Response object from entering participant
   * @param  {*}        [args] Both Scene and Dialogue constructor args
   * @param  {Function} [cb]   Called with context after enter middleware done
   * @return {Promise}         Resolves with final enter middleware context
  */
  sceneEnter (res, ...args) {
    const scene = new this.Scene(this.robot, ...args)
    const processEnter = scene.enter(res, ...args)
    this.scenes.push(scene)
    return processEnter
  }

  /**
   * Create scene and setup listener to enter.
   *
   * @param  {string}   type     Robot listener type: hear|respond
   * @param  {RegExp}   regex    Match pattern
   * @param  {*}        [args]   Scene constructor args
   * @param  {Function} callback Callback to fire after entered
   * @return {Scene}             New Scene instance
  */
  sceneListen (type, regex, ...args) {
    const callback = args.pop()
    const scene = this.scene(...args)
    scene.listen(type, regex, callback)
    return scene
  }

  /**
   * Alias of sceneListen with hear as specified type.
   *
   * @param  {*}   [args] Scene constructor args
  */
  sceneHear (...args) {
    return this.sceneListen('hear', ...args)
  }

  /**
   * Alias of sceneListen with respond as specified type.
   *
   * @param  {*}   [args] Scene constructor args
  */
  sceneRespond (...args) {
    return this.sceneListen('respond', ...args)
  }

  /**
   * Create new Director.
   *
   * @param  {*} [args] Director constructor args
   * @return {Director} New Director instance
  */
  director (...args) {
    const director = new this.Director(this.robot, ...args)
    this.directors.push(director)
    return director
  }

  /**
   * Create a transcript with optional config to record events from modules
   *
   * @param  {*}          [args] Transcript constructor args
   * @return {Transcript}        The new transcript
  */
  transcript (...args) {
    const transcript = new this.Transcript(this.robot, ...args)
    this.transcripts.push(transcript)
    return transcript
  }

  /**
   * Create transcript and record a given module in one step.
   *
   * @param  {*}  instance A Playbook module (dialogue, scene or director)
   * @param  {*}  [args]   Constructor args
   * @return {Transcript}  The new transcript
   *
   * @todo Allow passing instance key instead of object, to find from arrays
  */
  transcribe (instance, ...args) {
    const transcript = this.transcript(...args)
    if (instance instanceof this.Dialogue) transcript.recordDialogue(instance)
    if (instance instanceof this.Scene) transcript.recordScene(instance)
    if (instance instanceof this.Director) transcript.recordDirector(instance)
    return transcript
  }

  /**
   * Initialise Improv singleton module, or update configuration if exists.
   *
   * Access methods via `Playbook.improv` property.
   *
   * @param {Object} [options] Key/val options for config
   * @return {Improv}          Improv interface
  */
  improvise (options) {
    this.improv.use(this.robot)
    this.improv.configure(options)
    return this.improv
  }

  /**
   * Exit all scenes, end all dialogues.
   *
   * TODO: detach listeners for scenes, directors, transcripts and improv
  */
  shutdown () {
    if (this.log) this.log.info('Playbook shutting down')
    _.invokeMap(this.scenes, 'exitAll')
    _.invokeMap(this.dialogues, 'end')
  }

  /**
   * Shutdown and re-initialise instance (mostly for tests).
   *
   * @return {Playbook} - The reset instance
  */
  reset () {
    if (instance !== null) {
      instance.shutdown()
      instance.improv.reset()
      instance = null
    }
    return new Playbook()
  }

  /**
   * Load outline and setup scene listeners for _global_ bits.
   *
   * @param  {*} [args] Outline constructor args
   * @return {Playbook} The reset instance
   */
  outline (bits, ...args) {
    let outline = new this.Outline(this.robot, bits, ...args)
    outline.getSceneArgs().map((args) => this.sceneListen(...args))
    this.outlines.push(outline)
  }
}

module.exports = new Playbook()
