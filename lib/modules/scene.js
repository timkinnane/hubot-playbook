'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _toConsumableArray(arr) { if (Array.isArray(arr)) { for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) { arr2[i] = arr[i]; } return arr2; } else { return Array.from(arr); } }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var _ = require('lodash');
var Base = require('./base');
var Dialogue = require('./dialogue');
var Middleware = require('../utils/middleware');
require('../utils/string-to-regex');

/**
 * Scenes conduct participation in dialogue. They use listeners to enter an
 * audience into a new dialogue with the bot.
 *
 * Once entered into a scene, the audience is engaged and isolated from global
 * listeners. The bot will only respond to branches defined by dialogue in that
 * scene. The scope of audience can be:
 *
 * - user - engage the user (in any room)
 * - room - engage the whole room
 * - direct - engage the user in that room only
 *
 * @param {Robot} robot                   Hubot Robot instance
 * @param {Object} [options]              Key/val options for config
 * @param {string} [options.scope]        How to address participants: user(default)|room|direct
 * @param {boolean} [options.sendReplies] Toggle replying/sending (prefix message with "@user")
 * @param {string} [key]                  Key name for this instance
 *
 * @example
 * let roomScene = new Scene(robot, { scope: 'room' })
*/

var Scene = function (_Base) {
  _inherits(Scene, _Base);

  function Scene() {
    var _ref;

    _classCallCheck(this, Scene);

    for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }

    var _this = _possibleConstructorReturn(this, (_ref = Scene.__proto__ || Object.getPrototypeOf(Scene)).call.apply(_ref, [this, 'scene'].concat(args)));

    _this.defaults({ scope: 'user' });

    // setup internal middleware stack for processing entry
    _this.enterMiddleware = new Middleware(_this);

    // by default, prefix @user in room scene (to identify target recipient)
    if (_this.config.scope === 'room') _this.defaults({ sendReplies: true });

    var validTypes = ['room', 'user', 'direct'];
    if (!_.includes(validTypes, _this.config.scope)) _this.error('invalid scene scope');

    _this.engaged = {};
    _this.robot.receiveMiddleware(function (c, n, d) {
      return _this.middleware(c, n, d);
    });
    return _this;
  }

  /**
   * Process incoming messages, re-route to dialogue for engaged participants.
   *
   * @param {Object} context Passed through the middleware stack, with res
   * @param {Function} next  Called when all middleware is complete
   * @param {Function} done  Initial (final) completion callback
  */


  _createClass(Scene, [{
    key: 'middleware',
    value: function middleware(context, next, done) {
      var res = context.response;
      var participants = this.whoSpeaks(res);

      // are incoming messages from this scenes' engaged participants
      if (participants in this.engaged) {
        this.log.debug(participants + ' is engaged, routing dialogue.');
        res.finish(); // don't process regular listeners
        this.engaged[participants].receive(res); // let dialogue handle the response
        done(); // don't process further middleware.
      } else {
        this.log.debug(participants + ' not engaged, continue as normal.');
        next(done);
      }
    }

    /**
     * Add listener that enters the audience into the scene with callback, to then
     * add dialogue branches or process response as required.
     *
     * @param  {String} type       The listener type: hear|respond
     * @param  {RegExp} regex      Matcher for listener (accepts string, will cast as RegExp)
     * @param  {Function} callback Called when matched, with Response and Dialogue as arguments
     *
     * @example
     * let scene = new Scene(robot, { scope: 'user' })
     * scene.listen('respond', /hello/, (res) => {
     *   res.reply('you are now in a scene')
     *   // add dialogue branches now...
     * })
    */

  }, {
    key: 'listen',
    value: function listen(type, regex, callback) {
      var _this2 = this;

      if (!_.includes(['hear', 'respond'], type)) this.error('Invalid listener type');
      if (_.isString(regex) && _.isRegExp(regex.toRegExp())) regex = regex.toRegExp();
      if (!_.isRegExp(regex)) this.error('Invalid regex for listener');
      if (!_.isFunction(callback)) this.error('Invalid callback for listener');

      // setup listener with scene as attribute for later/external reference
      // may fail if enter hooks override (from Director)
      this.robot[type](regex, { id: this.id, scene: this }, function (res) {
        _this2.enter(res, function (context) {
          if (context.dialogue) callback(context.response, context);
        });
      });
    }

    /**
     * Alias of Scene.listen with `hear` as specified type.
    */

  }, {
    key: 'hear',
    value: function hear() {
      for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
        args[_key2] = arguments[_key2];
      }

      return this.listen.apply(this, ['hear'].concat(args));
    }

    /**
     * Alias of Scene.listen with `respond` as specified type.
    */

  }, {
    key: 'respond',
    value: function respond() {
      for (var _len3 = arguments.length, args = Array(_len3), _key3 = 0; _key3 < _len3; _key3++) {
        args[_key3] = arguments[_key3];
      }

      return this.listen.apply(this, ['respond'].concat(args));
    }

    /**
     * Identify the source of a message relative to the scene scope.
     *
     * @param  {Response} res Hubot Response object
     * @return {string}       ID of room, user or composite
    */

  }, {
    key: 'whoSpeaks',
    value: function whoSpeaks(res) {
      switch (this.config.scope) {
        case 'room':
          return res.message.room.toString();
        case 'user':
          return res.message.user.id.toString();
        case 'direct':
          return res.message.user.id + '_' + res.message.room;
      }
    }

    /**
      * Add a function to the enter middleware stack, to continue or interrupt the
      * pipeline. Called with:
      * - bound 'this' containing the current scene
      * - context, object containing relevant attributes for the pipeline
      * - next, function to call to continue the pipeline
      * - done, final pipeline function, optionally given as argument to next
      *
      * @param  {Function} piece Pipeline function to add to the stack.
     */

  }, {
    key: 'registerMiddleware',
    value: function registerMiddleware(piece) {
      this.enterMiddleware.register(piece);
    }

    /*
     * Trrgger scene enter middleware to begin, calling optional callback if/when
     * pipeline completes. Processing may reject promise, so should be caught.
     *
     * @param  {Response} res        Hubot Response object
     * @param  {Object} [options]    Dialogue options merged with scene config
     * @param  {*} args              Any additional args for Dialogue constructor
     * @param  {Function} [callback] Called after middleware with final context
     * @return {Promise}             Resolves with new Dialogue middleware completes
    */

  }, {
    key: 'enter',
    value: function enter(res) {
      for (var _len4 = arguments.length, args = Array(_len4 > 1 ? _len4 - 1 : 0), _key4 = 1; _key4 < _len4; _key4++) {
        args[_key4 - 1] = arguments[_key4];
      }

      var participants = this.whoSpeaks(res);
      if (this.inDialogue(participants)) return Promise.reject(new Error('Already engaged'));

      var callback = void 0; // not required (undefined by default)
      if (_.isFunction(args[args.length - 1])) callback = args.pop();

      var options = _.isObject(args[0]) ? args.shift() : {};
      options = _.defaults({}, this.config, options);

      // setup context and execute middleware stack, calling processEnter as
      // final step if pipeline is allowed to complete
      return this.enterMiddleware.execute({
        response: res,
        participants: participants,
        options: options,
        arguments: args
      }, this.processEnter.bind(this), callback);
    }

    /**
     * Engage the participants in dialogue. A new Dialogue instance is created and
     * all further messages from the audience in this scene's scope will be passed
     * to that dialogue, untill they are exited from the scene.
     *
     * Would usually be invoked as the final piece of enter middleware, after
     * stack execution is triggered by a scene listener but could be called
     * directly to force audience into a scene unprompted.
     *
     * @param  {Object} context              The final context after middleware completed
     * @param  {Object} context.response     The hubot response object
     * @param  {string} context.participants Who is being entered to the scene
     * @param  {Object} [context.options]    Options object given to dialogue
     * @param  {Array}  [context.arguments]  Additional arguments given to dialogue
     * @param  {Function} [done]             Optional final callback after processed - given context
     * @return {Dialogue}                    The final dialogue
     */

  }, {
    key: 'processEnter',
    value: function processEnter(context, done) {
      var _this3 = this;

      var args = Array.from(context.arguments);
      var dialogue = new (Function.prototype.bind.apply(Dialogue, [null].concat([context.response, context.options], _toConsumableArray(args))))();
      dialogue.scene = this;
      if (!dialogue.key && this.key) dialogue.key = this.key;
      dialogue.on('timeout', function (lastRes, other) {
        return _this3.exit(lastRes, 'timeout');
      });
      dialogue.on('end', function (lastRes) {
        var isComplete = lastRes.dialogue.path ? lastRes.dialogue.path.closed : false;
        return _this3.exit(lastRes, (isComplete ? '' : 'in') + 'complete');
      });
      this.engaged[context.participants] = dialogue;
      this.emit('enter', context.response, dialogue);
      this.log.info('Engaging ' + this.config.scope + ' ' + context.participants + ' in dialogue');
      context.dialogue = dialogue;
      process.nextTick(function () {
        return done(context);
      });
      return dialogue;
    }

    /**
     * Disengage participants from dialogue e.g. in case of timeout or error.
     *
     * @param  {Response} res    Hubot Response object
     * @param  {string} [status] Some context, for logs
     * @return {boolean}         Exit success (may fail if already disengaged)
    */

  }, {
    key: 'exit',
    value: function exit(res) {
      var status = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : 'unknown';

      var participants = this.whoSpeaks(res);
      if (this.engaged[participants] != null) {
        this.engaged[participants].clearTimeout();
        delete this.engaged[participants];
        this.emit('exit', res, status);
        this.log.info('Disengaged ' + this.config.scope + ' ' + participants + ' (' + status + ')');
        return true;
      }
      this.log.debug('Cannot disengage ' + participants + ', not in scene');
      return false;
    }

    /**
     * End all engaged dialogues.
    */

  }, {
    key: 'exitAll',
    value: function exitAll() {
      this.log.info('Disengaging all in ' + this.config.scope + ' scene');
      _.invokeMap(this.engaged, 'clearTimeout');
      this.engaged = [];
    }

    /**
     * Get the dialogue for engaged participants (relative to scene scope).
     *
     * @param  {string} participants ID of user, room or composite
     * @return {Dialogue}            Engaged dialogue instance
    */

  }, {
    key: 'getDialogue',
    value: function getDialogue(participants) {
      return this.engaged[participants];
    }

    /**
     * Get the engaged status for participants.
     *
     * @param  {string} participants ID of user, room or composite
     * @return {boolean}             Is engaged status
    */

  }, {
    key: 'inDialogue',
    value: function inDialogue(participants) {
      return _.includes(_.keys(this.engaged), participants);
    }
  }]);

  return Scene;
}(Base);

exports.default = Scene;
module.exports = exports['default'];
//# sourceMappingURL=scene.js.map