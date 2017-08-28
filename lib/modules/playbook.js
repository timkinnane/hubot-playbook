'use strict';Object.defineProperty(exports, "__esModule", { value: true });var _createClass = function () {function defineProperties(target, props) {for (var i = 0; i < props.length; i++) {var descriptor = props[i];descriptor.enumerable = descriptor.enumerable || false;descriptor.configurable = true;if ("value" in descriptor) descriptor.writable = true;Object.defineProperty(target, descriptor.key, descriptor);}}return function (Constructor, protoProps, staticProps) {if (protoProps) defineProperties(Constructor.prototype, protoProps);if (staticProps) defineProperties(Constructor, staticProps);return Constructor;};}();var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);
var _dialogue = require('./dialogue');var _dialogue2 = _interopRequireDefault(_dialogue);
var _scene = require('./scene');var _scene2 = _interopRequireDefault(_scene);
var _director = require('./director');var _director2 = _interopRequireDefault(_director);
var _transcript = require('./transcript');var _transcript2 = _interopRequireDefault(_transcript);
var _outline = require('./outline');var _outline2 = _interopRequireDefault(_outline);
var _improv = require('./improv');var _improv2 = _interopRequireDefault(_improv);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}function _toConsumableArray(arr) {if (Array.isArray(arr)) {for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) {arr2[i] = arr[i];}return arr2;} else {return Array.from(arr);}}function _classCallCheck(instance, Constructor) {if (!(instance instanceof Constructor)) {throw new TypeError("Cannot call a class as a function");}}

var instance = void 0;

/**
                        * Playbook brings conversational context and branching to Hubot.
                        *
                        * Modules are available as properties and their instances as collection items.
                        *
                        * Uses singleton pattern to make sure only one Playbook is created when used
                        * in multiple script files loaded by the same Hubot.
                       */var

Playbook = function () {
  function Playbook() {_classCallCheck(this, Playbook);
    if (!instance) {
      this.dialogues = [];
      this.scenes = [];
      this.directors = [];
      this.transcripts = [];
      this.outlines = [];
      this.Scene = _scene2.default;
      this.Dialogue = _dialogue2.default;
      this.Director = _director2.default;
      this.Transcript = _transcript2.default;
      this.Outline = _outline2.default;
      this.improv = _improv2.default;
      instance = this;
    }
    return instance;
  }

  /**
     * Attach Playbook to robot unless already done.
     *
     * @param  {Robot}    robot       Hubot instance
     * @param  {boolean}  [improvise] Enable/disable improv module and middleware (default true)
     * @return {Playbook}             Self for chaining
    */_createClass(Playbook, [{ key: 'use', value: function use(
    robot) {var improvise = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : true;
      this.robot = robot;
      if (this.robot.playbook === this) return this.robot.playbook;
      this.robot.playbook = this;
      this.log = this.robot.logger;
      this.log.info('Playbook using ' + this.robot.name + ' bot');
      if (improvise) this.improvise();
      return this;
    }

    /**
       * Create stand-alone dialogue (not within scene).
       *
       * @param {Response} res Hubot Response object
       * @param  {*} [args]    Optional other Dialogue constructor args
       * @return {Dialogue}    New Dialogue instance
      */ }, { key: 'dialogue', value: function dialogue(
    res) {for (var _len = arguments.length, args = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {args[_key - 1] = arguments[_key];}
      var dialogue = new (Function.prototype.bind.apply(this.Dialogue, [null].concat([res], args)))();
      this.dialogues.push(dialogue);
      return dialogue;
    }

    /**
       * Create new Scene.
       *
       * @param  {*} [args] Optional Scene constructor args
       * @return {Scene}    New Scene instance
      */ }, { key: 'scene', value: function scene()
    {for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {args[_key2] = arguments[_key2];}
      var scene = new (Function.prototype.bind.apply(this.Scene, [null].concat([this.robot], args)))();
      this.scenes.push(scene);
      return scene;
    }

    /**
       * Create and enter Scene.
       *
       * @param  {Response} res     Response object from entering participant
       * @param  {*}   [args]       Both Scene and Dialogue constructor args
       * @return {Dialogue/boolean} Entered Dialogue or false if failed
      */ }, { key: 'sceneEnter', value: function sceneEnter(
    res) {for (var _len3 = arguments.length, args = Array(_len3 > 1 ? _len3 - 1 : 0), _key3 = 1; _key3 < _len3; _key3++) {args[_key3 - 1] = arguments[_key3];}
      var scene = new (Function.prototype.bind.apply(this.Scene, [null].concat([this.robot], args)))();
      var dialogue = scene.enter.apply(scene, [res].concat(args));
      this.scenes.push(scene);
      return dialogue;
    }

    /**
       * Create scene and setup listener to enter.
       *
       * @param  {string}   type     Robot listener type: hear|respond
       * @param  {RegExp}   regex    Match pattern
       * @param  {*}        [args]   Scene constructor args
       * @param  {Function} callback Callback to fire after entered
       * @return {Scene}             New Scene instance
      */ }, { key: 'sceneListen', value: function sceneListen(
    type, regex) {for (var _len4 = arguments.length, args = Array(_len4 > 2 ? _len4 - 2 : 0), _key4 = 2; _key4 < _len4; _key4++) {args[_key4 - 2] = arguments[_key4];}
      var callback = args.pop();
      var scene = this.scene.apply(this, args);
      scene.listen(type, regex, callback);
      return scene;
    }

    /**
       * Alias of sceneListen with hear as specified type.
       *
       * @param  {*}   [args] Scene constructor args
      */ }, { key: 'sceneHear', value: function sceneHear()
    {for (var _len5 = arguments.length, args = Array(_len5), _key5 = 0; _key5 < _len5; _key5++) {args[_key5] = arguments[_key5];}
      return this.sceneListen.apply(this, ['hear'].concat(args));
    }

    /**
       * Alias of sceneListen with respond as specified type.
       *
       * @param  {*}   [args] Scene constructor args
      */ }, { key: 'sceneRespond', value: function sceneRespond()
    {for (var _len6 = arguments.length, args = Array(_len6), _key6 = 0; _key6 < _len6; _key6++) {args[_key6] = arguments[_key6];}
      return this.sceneListen.apply(this, ['respond'].concat(args));
    }

    /**
       * Create new Director.
       *
       * @param  {*} [args] Director constructor args
       * @return {Director} New Director instance
      */ }, { key: 'director', value: function director()
    {for (var _len7 = arguments.length, args = Array(_len7), _key7 = 0; _key7 < _len7; _key7++) {args[_key7] = arguments[_key7];}
      var director = new (Function.prototype.bind.apply(this.Director, [null].concat([this.robot], args)))();
      this.directors.push(director);
      return director;
    }

    /**
       * Create a transcript with optional config to record events from modules
       *
       * @param  {*}          [args] Transcript constructor args
       * @return {Transcript}        The new transcript
      */ }, { key: 'transcript', value: function transcript()
    {for (var _len8 = arguments.length, args = Array(_len8), _key8 = 0; _key8 < _len8; _key8++) {args[_key8] = arguments[_key8];}
      var transcript = new (Function.prototype.bind.apply(this.Transcript, [null].concat([this.robot], args)))();
      this.transcripts.push(transcript);
      return transcript;
    }

    /**
       * Create transcript and record a given module in one step.
       *
       * @param  {*}  instance A Playbook module (dialogue, scene or director)
       * @param  {*}  [args]   Constructor args
       * @return {Transcript}  The new transcript
       *
       * @todo Allow passing instance key instead of object, to find from arrays
      */ }, { key: 'transcribe', value: function transcribe(
    instance) {for (var _len9 = arguments.length, args = Array(_len9 > 1 ? _len9 - 1 : 0), _key9 = 1; _key9 < _len9; _key9++) {args[_key9 - 1] = arguments[_key9];}
      var transcript = this.transcript.apply(this, args);
      if (instance instanceof this.Dialogue) transcript.recordDialogue(instance);
      if (instance instanceof this.Scene) transcript.recordScene(instance);
      if (instance instanceof this.Director) transcript.recordDirector(instance);
      return transcript;
    }

    /**
       * Initialise Improv singleton module, or update configuration if exists.
       *
       * Access methods via `Playbook.improv` property.
       *
       * @param {Object} [options] Key/val options for config
       * @return {Improv}          Improv interface
      */ }, { key: 'improvise', value: function improvise(
    options) {
      this.improv.use(this.robot);
      this.improv.configure(options);
      return this.improv;
    }

    /**
       * Exit all scenes, end all dialogues.
       *
       * TODO: detach listeners for scenes, directors, transcripts and improv
      */ }, { key: 'shutdown', value: function shutdown()
    {
      if (this.log) this.log.info('Playbook shutting down');
      _lodash2.default.invokeMap(this.scenes, 'exitAll');
      _lodash2.default.invokeMap(this.dialogues, 'end');
    }

    /**
       * Shutdown and re-initialise instance (mostly for tests).
       *
       * @return {Playbook} - The reset instance
      */ }, { key: 'reset', value: function reset()
    {
      if (instance !== null) {
        instance.shutdown();
        instance.improv.reset();
        instance = null;
      }
      return new Playbook();
    }

    /**
       * Load outline and setup scene listeners for _global_ bits.
       *
       * @param  {*} [args] Outline constructor args
       * @return {Playbook} The reset instance
       */ }, { key: 'outline', value: function outline(
    bits) {var _this = this;for (var _len10 = arguments.length, args = Array(_len10 > 1 ? _len10 - 1 : 0), _key10 = 1; _key10 < _len10; _key10++) {args[_key10 - 1] = arguments[_key10];}
      var outline = new (Function.prototype.bind.apply(this.Outline, [null].concat([this.robot, bits], args)))();
      outline.getSceneArgs().map(function (args) {return _this.sceneListen.apply(_this, _toConsumableArray(args));});
      this.outlines.push(outline);
    } }]);return Playbook;}();exports.default =


new Playbook();module.exports = exports['default'];
//# sourceMappingURL=playbook.js.map