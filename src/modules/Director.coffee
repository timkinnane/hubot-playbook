_ = require 'underscore'
hooker = require 'hooker'
{inspect} = require 'util'
{EventEmitter} = require 'events'

Helpers = require './Helpers'

# TODO: Add middleware, and method for regular listeners (not for a scene)

# Control listener access, such as, but not limited to, any attached to a scene
# Can operate as a blacklist or a whitelist, also allowing external logic
# accepts an authorise function to determine access (lists can overide):
# - will be passed either user or room name, to return bool to allow/deny
# without an authorise function:
# - if type is whitelist, ONLY those on it are allowed
# - if type is blacklist, ONLY those on it are denied
# use environment to set global behaviour for all directors
# - DENIED_REPLY for when user denied access
# - WHITELIST_USERNAMES inherited by whitelist type and username scope directors
# - WHITELIST_ROOMS inherited by whitelist type and room scope directors
# - BLACKLIST_USERNAMES inherited by blacklist type and username scope directors
# - BLACKLIST_ROOMS inherited by blacklist type and room scope directors
class Director extends EventEmitter

  # @param robot {Object} the hubot instance
  # @param authorise (optional) {Function} function for controlling access
  #   will receive the user or room name and response object to control access
  #   e.g. could pass function to check if user has a particular role
  # @param opts (optional) {Object} key/vals for config overides, e.g.
  #   - type: whitelist or blacklist (default: whitelist)
  #   - scope: user or room (default: user)
  #   - reply: when user denied access (default: "Sorry, I can't do that.")
  #   - key: string reference for logs, events
  constructor: (@robot, args...) ->
    @log = @robot.logger
    @names = []

    # take arguments in param order, for all optional arguments
    @authorise = if _.isFunction args[0] then args.shift()
    opts = if _.isObject args[0] then opts = args.shift() else {}

    # create an id using director scope (and key if given)
    @id = Helpers.keygen 'director', opts.key or undefined

    # extend options with defaults
    @config = _.defaults opts,
      type: 'whitelist'
      scope: 'username'
      deniedReply: process.env.DENIED_REPLY or "Sorry, I can't do that."

    # allow setting black/whitelisted names from env var (csv)
    if @config.type is 'whitelist'
      if @config.scope is 'username' and process.env.WHITELIST_USERNAMES?
        @names = process.env.WHITELIST_USERNAMES.split ','
      else if @config.scope is 'room' and process.env.WHITELIST_ROOMS?
        @names = process.env.WHITELIST_ROOMS.split ','
    else if @config.type is 'blacklist'
      if @config.scope is 'username' and process.env.BLACKLIST_USERNAMES?
        @names = process.env.BLACKLIST_USERNAMES.split ','
      else if @config.scope is 'room' and process.env.BLACKLIST_ROOMS?
        @names = process.env.BLACKLIST_ROOMS.split ','

    # validate loaded config
    if @config.type not in ['whitelist','blacklist']
      throw new Error "Invalid type - accepts only whitelist or blacklist"
    if @config.scope not in ['username','room']
      throw new Error "Invalid scope - accepts only username or room"

    @log.info "New #{ @config.scope } Director #{ @config.type }: #{ @id }"
    if @config.deniedReply?
      @log.info "replies '#{ @config.deniedReply }' if denied"

  # merge new usernames/rooms with listed names
  add: (names) ->
    @log.info "Adding #{ inspect names } to #{ @id } #{ @config.type }"
    names = [names] if not _.isArray names # cast single as array
    @names = _.union @names, names
    return

  # remove usernames/rooms from listed names
  remove: (names) ->
    @log.info "Removing #{ inspect names } from #{ @id } #{ @config.type }"
    names = [names] if not _.isArray names # cast single as array
    @names = _.without @names, names...
    return

  # determine if user has access, checking against usernames and rooms
  isAllowed: (res) ->
    name = switch @config.scope
      when 'username' then res.message.user.name
      when 'room' then res.message.room

    # let whitelist names through, block anyone else (if not using authorise)
    if @config.type is 'whitelist'
      return true if name in @names
      return false if not @authorise?

    # block blacklist names, let anyone else through (if not using authorise)
    if @config.type is 'blacklist'
      return false if name in @names
      return true if not @authorise?

    # authorise function can determine access if lists didn't
    return @authorise name, res if @authorise?

  # process a access or denial (either silently or with reply, as configured)
  process: (res) ->
    allowed = @isAllowed res
    user = res.message.user.name
    message = res.message.text

    # allow access
    if allowed
      @log.debug "#{ @id } allowed #{ user } on receiving #{ message }"
      return true

    # process denial
    @log.info "#{ @id } denied #{ user } on receiving: #{ message }"
    @emit 'denied', res
    res.reply @config.deniedReply if @config.deniedReply not in ['', null]
    return false

  # let this director control access to any listener matching regex
  # note - this uses listener middleware because we don't want it sending
  # denied reply every time a message matches, only if there was a listener
  directMatch: (regex) ->
    throw new Error "Invalid regex provided" if not _.isRegExp regex
    @log.info "#{ @id } now controlling access to listeners matching #{ regex }"
    @robot.listenerMiddleware (context, next, done) =>
      res = context.response
      if res.message.text.match(regex) and not @process res # matched, denied
        res.message.finish() # don't process this message further
        return done() # don't process further middleware
      return next done # nothing matched or user allowed

  # let this director control access to a listener by id (allow partial match)
  directListener: (id) ->
    @log.info "#{ @id } now controlling access to listener id matching #{ id }"
    @robot.listenerMiddleware (context, next, done) =>
      res = context.response
      listenerId = context.listener.options.id
      regex = new RegExp id, 'i' # case insensitive match
      if listenerId.match(regex) and not @process res # listener matched, denied
        res.message.finish() # don't process this message further
        return done() # don't process further middleware
      return next done # nothing matched or user allowed

  # let this director control access to a given scene
  directScene: (scene) ->
    @log.info "#{ @id } now controlling #{ scene.id }"

    # setup middleware to control access to the scene's listeners
    @directListener scene.id

    # hook into .enter to control access for manually entered scenes
    hooker.hook scene, 'enter', pre: (res) =>
      return hooker.preempt false if not @process res

module.exports = Director

# TODO: save/restore config in hubot brain against Director id if provided
# TODO: parse Playbook messages for template tags e.g. sorry {{ username }}
