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

function _toConsumableArray(arr) { if (Array.isArray(arr)) { for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) { arr2[i] = arr[i]; } return arr2; } else { return Array.from(arr); } }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

/**
 * Outlines are a conversation modelling schema / handler, with collections of
 * attributes for setting up scenes, dialogues, paths and directors, for
 * interactions defined as bits.
 *
 * Define a key and condition to execute each bit, either consecutively off a
 * prior bit, or with a listen attribute to become effectively a global entry
 * point to a scene.
 *
 * A subsequent bit can even lead back to it’s own parent or any other bit,
 * creating a mesh of possible conversational pathways.
 *
 * @param {string/Object[]} bits      Attributes to setup bits
 * @param {array}  bits[].send        String/s to send when doing bit (minimum requirement)
 * @param {string} [bits[].catch]     To send if response unmatched by listeners
 * @param {string} [bits[].condition] Converted to regex for listener to trigger bit
 * @param {string} [bits[].listen]    Type of listener (hear/respond) for scene entry bit
 * @param {string} [bits[].scene]     Scope for the scene (only used if it has a listen type)
 * @param {string} [bits[].key]       Key for scene and/or dialogue running the bit
 * @param {Object} [bits[].options]   Key/val options for scene and/or dialogue config
 * @param {array} [bits[].next]       Key/s (strings) for consequitive bits
 * @param {Object} [options]          Key/val options for outline config
 * @param {string} [key]              Key name for this instance
 *
 * @todo Add bit attribute for callback function as a key of extended response
 * @todo Add bit attribute for director whitelist/blacklist names and/or auth function
 */
var Outline = function (_Base) {
  _inherits(Outline, _Base);

  function Outline(robot, bits) {
    var _ref;

    _classCallCheck(this, Outline);

    for (var _len = arguments.length, args = Array(_len > 2 ? _len - 2 : 0), _key = 2; _key < _len; _key++) {
      args[_key - 2] = arguments[_key];
    }

    var _this = _possibleConstructorReturn(this, (_ref = Outline.__proto__ || Object.getPrototypeOf(Outline)).call.apply(_ref, [this, 'outline', robot].concat(args)));

    _this.scenes = [];
    _this.bits = bits;
    _lodash2.default.filter(_this.bits, 'listen').map(function (bit) {
      return _this.setupScene(bit);
    });
    return _this;
  }

  /**
   * Send messages and setup any following listeners for a bit.
   *
   * Called in an open dialogue, as a callback on entering the scene or
   * continuing from a prior bit. Adds the bit as a property of the response.
   *
   * @param  {Response} res Hubot Response object
   * @param  {string} key   The key for a loaded bit
   */


  _createClass(Outline, [{
    key: 'doBit',
    value: function doBit(res, key) {
      var _setupDialogue;

      res.bit = this.bits[key];
      (_setupDialogue = this.setupDialogue(res)).send.apply(_setupDialogue, _toConsumableArray(res.bit.send));
      if (res.bit.next) this.setupPath(res);
    }

    /**
     * Prepare the arguments required to add listener for a scene entering bit.
     *
     * Only applicable to bits with a `listen` attribute (hear or respond).
     * Subsequent bits will play out within the same scene so their listen type is
     * irrelevant because all responses from an engaged audience will be routed
     * through the current dialogue.
     *
     * Bits only require a `.listen` and `.condition` property to setup a scene
     * listener and will use defaults if `.scope` and `.options` are null.
     *
     * @param  {Object} bit Attributes to setup scene for entry to bit
     */

  }, {
    key: 'setupScene',
    value: function setupScene(bit) {
      var _this2 = this;

      if (bit.listen !== null) {
        this.scenes.push({
          listen: bit.listen,
          regex: this.bitCondition(bit.key),
          type: bit.scope,
          options: bit.options,
          key: bit.key,
          callback: function callback(res) {
            return _this2.doBit(res, bit.key);
          }
        });
      }
    }

    /**
     * Get arguments to pass into scene listeners for _global_ bits.
     *
     * @return {array} Items contain required arguments (call with spread syntax)
     *
     * @example <caption>The hard way</caption>
     * const scene = new Scene(robot)
     * const outline = new Outline('./conversation.yml')
     * outline.getSceneArgs().map((args) => scene.listen(...args)
     *
     * @example <caption>The easy way</caption>
     * const pb = new Playbook(robot).outline('./conversation.yml')
     * // ^ playbook helper creates outline and sets up scenes
     */

  }, {
    key: 'getSceneArgs',
    value: function getSceneArgs() {
      return this.scenes.map(function (scene) {
        return [scene.listen, scene.regex, scene.type, scene.options, scene.callback];
      });
    }

    /**
     * Dialogue is already open from the scene being triggered.
     *
     * @param  {Response} res Hubot Response object
     */

  }, {
    key: 'setupDialogue',
    value: function setupDialogue(res) {
      var options = {};
      var bit = res.bit;
      var dialogue = res.dialogue;
      if (bit.reply !== null) options.sendReplies = bit.reply;
      if (bit.timeout !== null) options.timeout = bit.timeout;
      if (bit.timeoutText !== null) options.timeoutText = bit.timeout;
      dialogue.configure(options);
      dialogue.key = bit.key;
      return dialogue;
    }

    /**
     * Add path options and branches to
     *
     * @param  {Response} res Hubot Response object
     */

  }, {
    key: 'setupPath',
    value: function setupPath(res, dlg) {
      var _this3 = this;

      var bit = res.bit;
      var options = {};
      if (bit.catch) options.catchMessage = bit.catch;
      var branches = bit.next.map(function (nextKey) {
        var regex = _this3.bitCondition(nextKey);
        var callback = function callback(res) {
          return _this3.doBit(res, nextKey);
        };
        return [regex, callback];
      });
      dlg.addPath(branches, options, bit.key);
    }

    /**
     * Convert a bit's condition attribute into a regex.
     *
     * @param  {string} key The key for a loaded bit
     * @return {RegExp}     The pattern for the bit's listener
     *
     * @todo Use `conditioner-regex` to convert array of conditions to pattern
     */

  }, {
    key: 'bitCondition',
    value: function bitCondition(key) {
      return new RegExp('\\b' + this.bits[key].condition + '\\b', 'i');
    }
  }]);

  return Outline;
}(_base2.default);

exports.default = Outline;
module.exports = exports['default'];
//# sourceMappingURL=outline.js.map