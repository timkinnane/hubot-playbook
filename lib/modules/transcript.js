'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

var _lodash = require('lodash');

var _lodash2 = _interopRequireDefault(_lodash);

var _base = require('./base');

var _base2 = _interopRequireDefault(_base);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

_lodash2.default.mixin({
  'hasKeys': function hasKeys(obj, keys) {
    return _lodash2.default.size(_lodash2.default.difference(keys, _lodash2.default.keys(obj))) === 0;
  }
});
_lodash2.default.mixin({
  'pickHas': function pickHas(obj, pickKeys) {
    return _lodash2.default.omitBy(_lodash2.default.pick(obj, pickKeys), _lodash2.default.isUndefined);
  }
});

/**
 * Transcripts record conversation events, including meta about the user,
 * message and current module.
 *
 * Transcripts are searchable, to provide context from conversation history with
 * a given user, or based on any other attribute, such as listener ID.
 *
 * Different instances can be configured to record an overview or drilled down
 * analytics for a specific module’s interactions using its key.
 *
 * @param {Robot}  robot                  Hubot Robot instance
 * @param {Object} [options]              Key/val options for config
 * @param {Object} [options.save]         Store records in hubot brain
 * @param {array} [options.events]        Event names to record
 * @param {array} [options.responseAtts]  Response keys or paths to record
 * @param {array} [options.instanceAtts]  Module instance keys or paths to record
 * @param {string} [key]                  Key name for this instance
 *
 * @todo Add config to record response middleware context including listener ID
 *
 * @example <caption>transcript to record room name when match emitted</caption>
 * let matchRecordRooms = new Transcript(robot, {
 *   responseAtts: ['message.room']
 *   events: ['match']
 * })
 * // does not start recording until calling one of the record methods, like:
 * matchRecordRooms.recordAll()
*/

var Transcript = function (_Base) {
  _inherits(Transcript, _Base);

  function Transcript() {
    var _ref;

    _classCallCheck(this, Transcript);

    for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }

    var _this = _possibleConstructorReturn(this, (_ref = Transcript.__proto__ || Object.getPrototypeOf(Transcript)).call.apply(_ref, [this, 'transcript'].concat(args)));

    _this.defaults({
      save: true,
      events: ['match', 'mismatch', 'catch', 'send'],
      instanceAtts: ['name', 'key', 'id'],
      responseAtts: ['match'],
      messageAtts: ['user.id', 'user.name', 'room', 'text']
    });
    if (_this.config.instanceAtts != null) _lodash2.default.castArray(_this.config.instanceAtts);
    if (_this.config.responseAtts != null) _lodash2.default.castArray(_this.config.responseAtts);
    if (_this.config.messageAtts != null) _lodash2.default.castArray(_this.config.messageAtts);

    if (_this.config.save) {
      if (!_this.robot.brain.get('transcripts')) {
        _this.robot.brain.set('transcripts', []);
      }
      _this.records = _this.robot.brain.get('transcripts');
    }
    if (_this.records == null) _this.records = [];
    return _this;
  }

  /**
   * Record given event details in array, save to hubot brain if configured to.
   *
   * Events emitted by Playbook always include module instance as first param.
   *
   * This is only called internally on watched events after running `recordAll`,
   * `recordDialogue`, `recordScene` or `recordDirector`
   *
   * @param {string} event The event name
   * @param {*} args...    Args passed with the event, usually consists of:<br>
   *                       - Playbook module instance<br>
   *                       - Hubot response object<br>
   *                       - other additional (special context) arguments
  */


  _createClass(Transcript, [{
    key: 'recordEvent',
    value: function recordEvent(event) {
      var instance = void 0,
          response = void 0;

      for (var _len2 = arguments.length, args = Array(_len2 > 1 ? _len2 - 1 : 0), _key2 = 1; _key2 < _len2; _key2++) {
        args[_key2 - 1] = arguments[_key2];
      }

      if (_lodash2.default.hasKeys(args[0], ['name', 'id', 'config'])) instance = args.shift();
      if (_lodash2.default.hasKeys(args[0], ['robot', 'message'])) response = args.shift();
      var record = { time: _lodash2.default.now(), event: event };
      if (this.key != null) record.key = this.key;
      if (instance != null && this.config.instanceAtts != null) {
        record.instance = _lodash2.default.pickHas(instance, this.config.instanceAtts);
      }
      if (response != null && this.config.responseAtts != null) {
        record.response = _lodash2.default.pickHas(response, this.config.responseAtts);
      }
      if (response != null && this.config.messageAtts != null) {
        record.message = _lodash2.default.pickHas(response.message, this.config.messageAtts);
      }

      if (!_lodash2.default.isEmpty(args)) {
        if (event === 'send' && args[0].strings) record.strings = args[0].strings;else record.other = args;
      }

      this.records.push(record);
      this.emit('record', record);
    }

    /**
     * Record events emitted by all Playbook modules and/or the robot itself
     * (still only applies to configured event types).
    */

  }, {
    key: 'recordAll',
    value: function recordAll() {
      var _this2 = this;

      _lodash2.default.castArray(this.config.events).map(function (event) {
        return _this2.robot.on(event, function () {
          for (var _len3 = arguments.length, args = Array(_len3), _key3 = 0; _key3 < _len3; _key3++) {
            args[_key3] = arguments[_key3];
          }

          return _this2.recordEvent.apply(_this2, [event].concat(args));
        });
      });
    }

    /**
     * @todo Re-instate `recordListener` when regular listeners emit event with
     * context containing options and ID.
     */
    /*
    recordListener (context) {
     }
    */

    /**
     * Record events emitted by a given dialogue and it's path/s.
     *
     * Whenever a path is added to a dialogue, event handlers are added on the
     * path for the configured events.
     *
     * @param {Dialogue} dialogue The Dialogue instance
    */

  }, {
    key: 'recordDialogue',
    value: function recordDialogue(dialogue) {
      var _this3 = this;

      var dialogueEvents = _lodash2.default.intersection(this.config.events, ['end', 'send', 'timeout', 'path']);
      var pathEvents = _lodash2.default.intersection(this.config.events, ['match', 'catch', 'mismatch']);
      dialogueEvents.map(function (event) {
        dialogue.on(event, function () {
          for (var _len4 = arguments.length, args = Array(_len4), _key4 = 0; _key4 < _len4; _key4++) {
            args[_key4] = arguments[_key4];
          }

          return _this3.recordEvent.apply(_this3, [event, dialogue].concat(args));
        });
      });
      dialogue.on('path', function (path) {
        pathEvents.map(function (event) {
          path.on(event, function () {
            for (var _len5 = arguments.length, args = Array(_len5), _key5 = 0; _key5 < _len5; _key5++) {
              args[_key5] = arguments[_key5];
            }

            return _this3.recordEvent.apply(_this3, [event, path].concat(args));
          });
        });
      });
    }

    /**
     * Record events emitted by a given scene and any dialogue it enters, captures
     * configured events from scene and its created dialogues and paths.
     *
     * @param {Scene} scene The Scnee instance
    */

  }, {
    key: 'recordScene',
    value: function recordScene(scene) {
      var _this4 = this;

      scene.on('enter', function (res) {
        if (_lodash2.default.includes(_this4.config.events, 'enter')) _this4.recordEvent('enter', scene, res);
        _this4.recordDialogue(res.dialogue);
      });
      scene.on('exit', function () {
        for (var _len6 = arguments.length, args = Array(_len6), _key6 = 0; _key6 < _len6; _key6++) {
          args[_key6] = arguments[_key6];
        }

        if (_lodash2.default.includes(_this4.config.events, 'exit')) _this4.recordEvent.apply(_this4, ['exit', scene].concat(args));
      });
    }

    /**
     * Record allow/deny events emitted by a given director. Ignores configured
     * events because director has distinct events.
     *
     * @param {Director} director The Director instance
    */

  }, {
    key: 'recordDirector',
    value: function recordDirector(director) {
      var _this5 = this;

      director.on('allow', function () {
        for (var _len7 = arguments.length, args = Array(_len7), _key7 = 0; _key7 < _len7; _key7++) {
          args[_key7] = arguments[_key7];
        }

        return _this5.recordEvent.apply(_this5, ['allow', director].concat(args));
      });
      director.on('deny', function () {
        for (var _len8 = arguments.length, args = Array(_len8), _key8 = 0; _key8 < _len8; _key8++) {
          args[_key8] = arguments[_key8];
        }

        return _this5.recordEvent.apply(_this5, ['deny', director].concat(args));
      });
    }

    /**
     * Filter records matching a subset, e.g. user name or instance key.
     *
     * Optionally return the whole record or values for a given key.
     *
     * @param  {Object} subsetMatch  Key/s:value/s to match (accepts path key)
     * @param  {string} [returnPath] Key or path within record to return
     * @return {array}               Whole records or selected values found
     *
     * @example
     * transcript.findRecords({
     *   message: { user: { name: 'jon' } }
     * })
     * // returns array of recorded event objects
     *
     * transcript.findRecords({
     *   message: { user: { name: 'jon' } }
     * }, 'message.text')
     * // returns array of message text attribute from recroded events
    */

  }, {
    key: 'findRecords',
    value: function findRecords(subsetMatch, returnPath) {
      var found = _lodash2.default.filter(this.records, subsetMatch);
      if (returnPath == null) return found;
      var foundAtPath = found.map(function (record) {
        return (0, _lodash2.default)(record).at(returnPath).head();
      });
      _lodash2.default.remove(foundAtPath, _lodash2.default.isUndefined);
      return foundAtPath;
    }

    /**
     * Alias for findRecords for just response match attributes with a given
     * instance key, useful for simple lookups of information provided by users
     * within a specific conversation.
     *
     * @param  {string}  instanceKey    Recorded instance key to lookup
     * @param  {string}  [userId]       Filter results by a user ID
     * @param  {integer} [captureGroup] Filter match by regex capture group subset
     * @return {array}                  Contains full match or just capture group
     *
     * @example <caption>find answers from a specific dialogue path</caption>
     * const transcript = new Transcript(robot)
     * robot.hear(/color/, (res) => {
     *   let favColor = new Dialogue(res, 'fav-color')
     *   transcript.recordDialogue(favColor)
     *   favColor.addPath([
     *     [ /my favorite color is (.*)/, 'duly noted' ]
     *   ])
     *   favColor.receive(res)
     * })
     * robot.respond(/what is my favorite color/, (res) => {
     *   let colorMatches = transcript.findKeyMatches('fav-color', 1)
     *   # ^ word we're looking for from capture group is at index: 1
     *   if (colorMatches.length) {
     *     res.reply(`I remember, it's ${ colorMatches.pop() }`)
     *   } else {
     *     res.reply("I don't know!?")
     *   }
     * })
     *
    */

  }, {
    key: 'findKeyMatches',
    value: function findKeyMatches(instanceKey) {
      for (var _len9 = arguments.length, args = Array(_len9 > 1 ? _len9 - 1 : 0), _key9 = 1; _key9 < _len9; _key9++) {
        args[_key9 - 1] = arguments[_key9];
      }

      var userId = _lodash2.default.isString(args[0]) ? args.shift() : null;
      var captureGroup = _lodash2.default.isInteger(args[0]) ? args.shift() : null;
      var subset = { instance: { key: instanceKey } };
      var path = 'response.match';
      if (userId != null) _lodash2.default.extend(subset, { message: { user: { id: userId } } });
      if (captureGroup != null) path += '[' + captureGroup + ']';
      return this.findRecords(subset, path);
    }

    /**
     * Alias for findRecords for just response match attributes with a given
     * listener ID, useful for lookups of matches from a specific listener.
     *
     * @param  {string}  listenerId     Listener ID match to lookup
     * @param  {string}  [userId]       Filter results by a user ID
     * @param  {integer} [captureGroup] Filter match by regex capture group subset
     * @return {array}                  Contains full match or just capture group
     *
     * @todo Re-instate `findIdMatches` when `recordListener` is funtional
    */
    /*
    findIdMatches (listenerId, ...args) {
      let userId = (_.isString(args[0])) ? args.shift() : null
      let captureGroup = (_.isInteger(args[0])) ? args.shift() : null
      let subset = { listener: { options: { id: listenerId } } }
      let path = 'response.match'
      if (userId != null) subset.message = { user: { id: userId } }
      if (captureGroup != null) path += `[${captureGroup}]`
      return this.findRecords(subset, path)
    }
    */

  }]);

  return Transcript;
}(_base2.default);

exports.default = Transcript;
module.exports = exports['default'];
//# sourceMappingURL=transcript.js.map