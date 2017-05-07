_ = require 'lodash'
Base = require './Base'
hooker = require 'hooker'

###*
 * Control listener and scene enter access, operates as blacklist or whitelist.
 * Allows external logic via authorise...
 * - given the user or room name and response object to allow or deny
 * - return bool to determine access as fallback for anyone not on lists
 * - e.g. pass a function to check if user has a particular role in platform
 * @param  {Robot}    robot       - Hubot Robot instance
 * @param  {Function} [authorise] - Function to determine access (as fallback)
 * @param  {Object}   [opts]      - Config key/vals:
 *                    - type: whitelist or blacklist (default: whitelist)
 *                    - scope: user or room (default: user)
 *                    - deniedReply: sends when denied access
 *                    - key: string reference for logs, events
###
class Director extends Base
  constructor: (robot, args...) ->
    @defaults =
      type: 'whitelist'
      scope: 'username'
      deniedReply: process.env.DENIED_REPLY or "Sorry, I can't do that."
    @authorise = if _.isFunction args[0] then args.shift()
    opts = if _.isObject args[0] then opts = args.shift() else {}
    super 'director', robot, opts
    @error "Invalid type" unless @config.type in ['whitelist', 'blacklist']
    @error "Invalid scope" unless @config.scope in ['username', 'room']
    @log.info "New #{ @config.scope } Director #{ @config.type }: #{ @id }"

    # Process environment settings for default lists
    # - WHITELIST_USERNAMES for whitelist type and username scope directors
    # - WHITELIST_ROOMS for whitelist type and room scope directors
    # - BLACKLIST_USERNAMES for blacklist type and username scope directors
    # - BLACKLIST_ROOMS for blacklist type and room scope directors
    listEnv = @config.type.toUpperCase()
    @names = switch @config.scope
      when 'username' then process.env["#{ listEnv }_USERNAMES"]
      when 'room' then process.env["#{ listEnv }_ROOMS"]
    @names = @names.split ',' if @names?
    @names ?= []

  ###*
   * Add new usernames/rooms to list
   * @param  {String|Array} names - Usernames or Room names (depending on scope)
   * @return {Director}           - Self, for chaining methods
  ###
  add: (names) ->
    @log.info "Adding #{ names.toString() } to #{ @id } #{ @config.type }"
    @names = _.union @names, _.castArray names
    return @

  ###*
   * Remove new usernames/rooms from list
   * @param  {String|Array} names - Usernames or Room names (depending on scope)
   * @return {Director}           - Self, for chaining methods
  ###
  remove: (names) ->
    @log.info "Removing #{ names.toString() } from #{ @id } #{ @config.type }"
    @names = _.without @names, _.castArray(names)...
    return @

  ###*
   * Determine if user has access, checking usernames/rooms against lists
   * Blacklist blocks names on list, let anyone else through
   # Whitelist lets names on list through, block anyone else
   * @param  {Response} res - Hubot Response object
   * @return {Boolean}      - Access allowed
  ###
  isAllowed: (res) ->
    name = switch @config.scope
      when 'username' then res.message.user.name
      when 'room' then res.message.room

    if @config.type is 'blacklist'
      return false if name in @names
      return true if not @authorise?
    else
      return true if name in @names
      return false if not @authorise?

    # authorise function can determine access if lists didn't
    return @authorise name, res if @authorise?

  ###*
   * Process access or denial (either silently or with reply, as configured)
   * @param  {Response} res - Hubot Response object
   * @return {Boolean}      - Access allowed
  ###
  process: (res) ->
    allowed = @isAllowed res
    user = res.message.user.name
    message = res.message.text
    if allowed
      @log.debug "#{ @id } allowed #{ user } on receiving #{ message }"
      @emit 'allow', res
      return true
    else
      @log.info "#{ @id } denied #{ user } on receiving: #{ message }"
      @emit 'deny', res
      res.reply @config.deniedReply if @config.deniedReply not in ['', null]
      return false

  ###*
   * Let this director control access to any listener matching regex
   * @param  {Regex}  regex - Listener match pattern
   * @return {Director}     - Self, for chaining methods
  ###
  directMatch: (regex) ->
    @error "Invalid regex" if not _.isRegExp regex
    @log.info "#{ @id } now controlling access to listeners matching #{ regex }"
    @robot.listenerMiddleware (context, next, done) =>
      res = context.response
      isMatch = res.message.text.match regex
      isDenied = not @process res
      if isMatch and isDenied
        res.message.finish() # don't process this message further
        return done() # don't process further middleware
      return next done # nothing matched or user allowed
    return @

  ###*
   * Let this director control access to a listener by listener or scene ID
   * If multiple listeners use the same ID, it's assumed to deny all of them
   * @param  {String}   id - ID of listener (may be multiple for scene)
   * @return {Director}    - Self, for chaining methods
  ###
  directListener: (id) ->
    @log.info "Director #{ @id } now controlling access to listener #{ id }"
    @robot.listenerMiddleware (context, next, done) =>
      res = context.response
      isMatch = context.listener.options.id is id
      isDenied = not @process res
      if isMatch and isDenied
        context.response.message.finish() # don't process this message further
        return done() # don't process further middleware
      return next done # nothing matched or user allowed
    return @

  ###*
   * Let this director control access to a given scene's listener
   * Hooks into .enter method to control access for manually entered scenes
   * @param  {Scene} scene - The Scene instance
   * @return {Director}    - Self, for chaining methods
   * TODO: replace hooker usage with new Hubot.Middleware on scene enter
  ###
  directScene: (scene) ->
    @log.info "#{ @id } now controlling #{ scene.id }"
    @directListener scene.id #  to control scene's listeners
    hooker.hook scene, 'enter', pre: (res) =>
      return hooker.preempt false unless @process res
    return @

module.exports = Director
