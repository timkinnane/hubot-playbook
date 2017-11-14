'use strict'

const _ = require('lodash')
const Base = require('./base')

/**
 * Directors provide conversation firewalls, allowing listed users to be
 * authorised or blocked from entering scenes or preventing listeners from
 * firing.
 *
 * Access is determined by blacklist or whitelist, or if defined, a custom
 * fallback function can determine to allow or deny anyone not on the list.
 *
 * A director can be attached to whole scenes or dialogues, or even specific
 * listeners.
 *
 * _Authorise_ function is given the user or room name (depending on the scope
 * configured for the direcrot) and response object. It must return a boolean to
 * determine access.
 *
 * `config.deniedReply` can be set globally with environment var `DENIED_REPLY`
 *
 * Environment vars can also provide global default lists:
 * - `WHITELIST_USERNAMES` for whitelist type and username scope directors
 * - `WHITELIST_ROOMS` for whitelist type and room scope directors
 * - `BLACKLIST_USERNAMES` for blacklist type and username scope directors
 * - `BLACKLIST_ROOMS` for blacklist type and room scope directors
 *
 * @param {Robot}    robot               Hubot Robot instance
 * @param {Function} [authorise]         Function to determine access (as fallback)
 * @param {Object} [options]             Key/val options for config
 * @param {string} [options.type]        'whitelist' (default) or 'blacklist'
 * @param {string} [options.scope]       'username' (default) or 'room'
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
class Director extends Base {
  constructor (robot, ...args) {
    let authArg = _.isFunction(args[0]) ? args.shift() : null
    super('director', robot, ...args)
    this.defaults({
      type: 'whitelist',
      scope: 'username',
      deniedReply: process.env.DENIED_REPLY || null
    })
    this.authorise = authArg

    if (!_.includes(['whitelist', 'blacklist'], this.config.type)) this.error('Invalid type')
    if (!_.includes(['username', 'room'], this.config.scope)) this.error('Invalid scope')
    this.log.info(`New ${this.config.scope} Director ${this.config.type}`)

    const listEnv = this.config.type.toUpperCase()
    switch (this.config.scope) {
      case 'username': this.names = process.env[`${listEnv}_USERNAMES`]
        break
      case 'room': this.names = process.env[`${listEnv}_ROOMS`]
    }
    if (this.names != null) this.names = this.names.split(',')
    if (this.names == null) this.names = []
  }

  /**
   * Add new usernames/rooms to list.
   *
   * @param  {string/array} names Usernames or Room names (depending on scope)
   * @return {Director}           Self, for chaining methods
  */
  add (names) {
    this.log.info(`Adding ${names.toString()} to ${this.id} ${this.config.type}`)
    this.names = _.union(this.names, _.castArray(names))
    return this
  }

  /**
   * Remove new usernames/rooms from list.
   *
   * @param  {string/array} names Usernames or Room names (depending on scope)
   * @return {Director}           Self, for chaining methods
  */
  remove (names) {
    this.log.info(`Removing ${names.toString()} from ${this.id} ${this.config.type}`)
    this.names = _.without(this.names, ..._.castArray(names))
    return this
  }

  /**
   * Determine if user has access, checking usernames/rooms against lists.
   *
   * _Blacklist_ blocks names on list, let anyone else through. _Whitelist_ lets
   * names on list through, block anyone else. Whitelist is default behaviour.
   *
   * @param  {Response} res    Hubot Response object
   * @return {Boolean/Promise} Access allowed - should wrap in resolve
   *
   * @example <caption>assumes res1, res2 are valid Response objects</caption>
   * let noHomers = new Director(robot, { type: 'blacklist' }).add('homer')
   * res1.message.user.name = 'homer'
   * res2.message.user.name = 'marge'
   * noHomers.isAllowed(res1) // false
   * noHomers.isAllowed(res2) // true
  */
  isAllowed (res) {
    let name
    switch (this.config.scope) {
      case 'username': name = res.message.user.name
        break
      case 'room': name = res.message.room
    }

    if (this.config.type === 'blacklist') {
      if (_.includes(this.names, name)) return false
      if (this.authorise == null) return true
    } else {
      if (_.includes(this.names, name)) return true
      if (this.authorise == null) return false
    }
    return this.authorise(name, res)
  }

  /**
   * Process access or denial (either silently or with reply, as configured).
   *
   * @param  {Response} res Hubot Response object
   * @return {Promise}      Resolves with boolean, access allowed/denied
  */
  process (res) {
    const isAllowed = Promise.resolve(this.isAllowed(res))
    const user = res.message.user.name
    const message = res.message.text
    return isAllowed.then((allowed) => {
      if (allowed) {
        this.log.debug(`${this.id} allowed ${user} on receiving ${message}`)
        this.emit('allow', res)
      } else {
        this.log.info(`${this.id} denied ${user} on receiving: ${message}`)
        this.emit('deny', res)
        if (!_.includes(['', null], this.config.deniedReply)) res.reply(this.config.deniedReply)
      }
      return allowed
    })
  }

  /**
   * Let this director control access to any listener matching regex.
   *
   * @param  {Regex}  regex Listener match pattern
   * @return {Director}     Self, for chaining methods
  */
  directMatch (regex) {
    this.log.info(`Now directing access to listeners matching ${regex}`)
    this.robot.listenerMiddleware((context, next, done) => {
      if (!context.response.message.text.match(regex)) return next(done)
      this.process(context.response).then((allowed) => {
        if (allowed) return next(done)
        context.response.message.finish() // don't process this message further
        return done() // don't process further middleware
      })
    }) // nothing matched or user allowed
    return this
  }

  /**
   * Let this director control access to a listener by listener ID.
   *
   * If multiple listeners use the same ID, it's assumed to deny all of them.
   *
   * @param  {string}   id Listener ID (may be multiple for scene)
   * @return {Director}    Self, for chaining methods
  */
  directListener (id) {
    this.log.info(`Now directing access to listener ${id}`)
    this.robot.listenerMiddleware((context, next, done) => {
      if (context.listener.options.id !== id) return next(done)
      this.process(context.response).then((allowed) => {
        if (allowed) return next(done)
        context.response.message.finish() // don't process this message further
        return done() // don't process further middleware
      })
    }) // nothing matched or user allowed
    return this
  }

  /**
   * Let this director control access to a given scene's listener.
   *
   * Also hooks into `Scene.enter` to control access to manually entered scenes.
   *
   * @param  {Scene} scene The Scene instance
   * @return {Director}    Self, for chaining methods
  */
  directScene (scene) {
    this.log.info(`Now directing access to ${scene.id} ${scene.key}`)
    const director = this
    scene.registerMiddleware((context, next, done) => {
      director.process(context.response).then((allowed) => {
        if (allowed) next(done)
        else done()
      })
    })
    return this
  }
}

module.exports = Director
