'use strict';

var _lodash = require('lodash');var _lodash2 = _interopRequireDefault(_lodash);
var _base = require('./base');var _base2 = _interopRequireDefault(_base);
var _hooker = require('hooker');var _hooker2 = _interopRequireDefault(_hooker);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

/**
                                                                                                                                                                              * Provides conversation firewalls, allowing listed users or custom logic to
                                                                                                                                                                              * authorise or block users from entering interactions or following specific
                                                                                                                                                                              * paths.
                                                                                                                                                                              *
                                                                                                                                                                              * Access is determined by blacklist or whitelist, or if defined a fallback
                                                                                                                                                                              * _authorise_ function to allow or deny anyone not on the list.
                                                                                                                                                                              *
                                                                                                                                                                              * Authorise callback is given the user or room name (depending on the scope
                                                                                                                                                                              * configured for the direcrot) and response object. It must return a boolean to
                                                                                                                                                                              * determine access.
                                                                                                                                                                              *
                                                                                                                                                                              * @param {Robot}    robot               Hubot Robot instance
                                                                                                                                                                              * @param {Function} [authorise]         Function to determine access (as fallback)
                                                                                                                                                                              * @param {Object} [options]             Key/val options for config
                                                                                                                                                                              * @param {string} [options.type]        `'whitelist'` (default) or `'blacklist'`
                                                                                                                                                                              * @param {string} [options.deniedReply] Sent when denied access
                                                                                                                                                                              * @param {string} [key]                 Key name for this instance
                                                                                                                                                                              *
                                                                                                                                                                              *
                                                                                                                                                                              * @example <caption>check if user has a particular role in platform</caption>
                                                                                                                                                                              * let adminsOnly = new Director(robot, (username) => {
                                                                                                                                                                              *   return chatPlatform.userHasPermission(username, 'admin')
                                                                                                                                                                              * })
                                                                                                                                                                              * // ...when directing a scene, will only allow platform admins to enter.
                                                                                                                                                                             */
class Director extends _base2.default {
  /**
                                        * `config.deniedReply` can be set globally with environment var `DENIED_REPLY`
                                        *
                                        * Environment vars can also provide global default lists:
                                        * - `WHITELIST_USERNAMES` for whitelist type and username scope directors
                                        * - `WHITELIST_ROOMS` for whitelist type and room scope directors
                                        * - `BLACKLIST_USERNAMES` for blacklist type and username scope directors
                                        * - `BLACKLIST_ROOMS` for blacklist type and room scope directors
                                        */
  constructor(robot, ...args) {
    let authArg = _lodash2.default.isFunction(args[0]) ? args.shift() : null;
    super('director', robot, ...args);
    this.defaults({
      type: 'whitelist',
      scope: 'username',
      deniedReply: process.env.DENIED_REPLY || "Sorry, I can't do that." });

    this.authorise = authArg;

    if (!['whitelist', 'blacklist'].includes(this.config.type)) this.error('Invalid type');
    if (!['username', 'room'].includes(this.config.scope)) this.error('Invalid scope');
    this.log.info(`New ${this.config.scope} Director ${this.config.type}: ${this.id}`);

    const listEnv = this.config.type.toUpperCase();
    switch (this.config.scope) {
      case 'username':this.names = process.env[`${listEnv}_USERNAMES`];
        break;
      case 'room':this.names = process.env[`${listEnv}_ROOMS`];}

    if (this.names != null) this.names = this.names.split(',');
    if (this.names == null) this.names = [];
  }

  /**
     * Add new usernames/rooms to list.
     *
     * @param  {string/array} names Usernames or Room names (depending on scope)
     * @return {Director}           Self, for chaining methods
    */
  add(names) {
    this.log.info(`Adding ${names.toString()} to ${this.id} ${this.config.type}`);
    this.names = _lodash2.default.union(this.names, _lodash2.default.castArray(names));
    return this;
  }

  /**
     * Remove new usernames/rooms from list.
     *
     * @param  {string/array} names Usernames or Room names (depending on scope)
     * @return {Director}           Self, for chaining methods
    */
  remove(names) {
    this.log.info(`Removing ${names.toString()} from ${this.id} ${this.config.type}`);
    this.names = _lodash2.default.without(this.names, ..._lodash2.default.castArray(names));
    return this;
  }

  /**
     * Determine if user has access, checking usernames/rooms against lists.
     *
     * _Blacklist_ blocks names on list, let anyone else through. _Whitelist_ lets
     * names on list through, block anyone else. Whitelist is default behaviour.
     *
     * @param  {Response} res Hubot Response object
     * @return {boolean}      Access allowed
     *
     * @example <caption>assumes res1, res2 are valid Response objects</caption>
     * let noHomers = new Director(robot, { type: 'blacklist' }).add('homer')
     * res1.message.user.name = 'homer'
     * res2.message.user.name = 'marge'
     * noHomers.isAllowed(res1) // false
     * noHomers.isAllowed(res2) // true
    */
  isAllowed(res) {
    let name;
    switch (this.config.scope) {
      case 'username':name = res.message.user.name;
        break;
      case 'room':name = res.message.room;}


    if (this.config.type === 'blacklist') {
      if (this.names.includes(name)) return false;
      if (this.authorise == null) return true;
    } else {
      if (this.names.includes(name)) return true;
      if (this.authorise == null) return false;
    }
    return this.authorise(name, res);
  }

  /**
     * Process access or denial (either silently or with reply, as configured).
     *
     * @param  {Response} res Hubot Response object
     * @return {boolean}      Access allowed
    */
  process(res) {
    const allowed = this.isAllowed(res);
    const user = res.message.user.name;
    const message = res.message.text;
    if (allowed) {
      this.log.debug(`${this.id} allowed ${user} on receiving ${message}`);
      this.emit('allow', res);
      return true;
    } else {
      this.log.info(`${this.id} denied ${user} on receiving: ${message}`);
      this.emit('deny', res);
      if (!['', null].includes(this.config.deniedReply)) res.reply(this.config.deniedReply);
      return false;
    }
  }

  /**
     * Let this director control access to any listener matching regex.
     *
     * @param  {Regex}  regex - Listener match pattern
     * @return {Director}     - Self, for chaining methods
    */
  directMatch(regex) {
    this.log.info(`${this.id} now controlling access to listeners matching ${regex}`);
    this.robot.listenerMiddleware((context, next, done) => {
      const res = context.response;
      const isMatch = res.message.text.match(regex);
      const isDenied = !this.process(res);
      if (isMatch && isDenied) {
        res.message.finish(); // don't process this message further
        return done(); // don't process further middleware
      }
      return next(done);
    }); // nothing matched or user allowed
    return this;
  }

  /**
     * Let this director control access to a listener by listener or scene ID.
     *
     * If multiple listeners use the same ID, it's assumed to deny all of them.
     *
     * @param  {string}   id Listener ID (may be multiple for scene)
     * @return {Director}    Self, for chaining methods
    */
  directListener(id) {
    this.log.info(`Director ${this.id} now controlling access to listener ${id}`);
    this.robot.listenerMiddleware((context, next, done) => {
      const res = context.response;
      const isMatch = context.listener.options.id === id;
      const isDenied = !this.process(res);
      if (isMatch && isDenied) {
        context.response.message.finish(); // don't process this message further
        return done(); // don't process further middleware
      }
      return next(done);
    }); // nothing matched or user allowed
    return this;
  }

  /**
     * Let this director control access to a given scene's listener.
     *
     * Also hooks into `Scene.enter` to control access to manually entered scenes.
     *
     * @param  {Scene} scene The Scene instance
     * @return {Director}    Self, for chaining methods
     * @todo Replace hooker usage with custom middleware on scene enter.
     * e.g. https://gist.github.com/darrenscerri/5c3b3dcbe4d370435cfa
    */
  directScene(scene) {
    this.log.info(`${this.id} now controlling ${scene.id}`);
    this.directListener(scene.id); //  to control scene's listeners
    _hooker2.default.hook(scene, 'enter', {
      pre: res => {
        if (!this.process(res)) return _hooker2.default.preempt(false);
      } });

    return this;
  }}


module.exports = Director;