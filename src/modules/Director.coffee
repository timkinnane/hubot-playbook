_ = require 'underscore'
hooker = require 'hooker'
{inspect} = require 'util'
{generate} = require 'randomstring'
slug = require 'slug'
{EventEmitter} = require 'events'

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
  # @param key (optional) {String} name for references to instance, e.g. logs
  # @param authorise (optional) {Function} function for controlling access
  #   will receive the user or room name and response object to control access
  #   e.g. could pass function to check if user has a particular role
  # @param opts (optional) {Object} key/vals for config overides, e.g.
  #   - type: whitelist or blacklist (default: whitelist)
  #   - scope: user or room (default: user)
  #   - reply: when user denied access (default: "Sorry, I can't do that.")
  constructor: (@robot, args...) ->
    @log = @robot.logger
    @names = []

    # take args of the stack in param order, for all optional arguments
    @key = if _.isString args[0] then @keygen args.shift() else @keygen()
    @authorise = if _.isFunction args[0] then args.shift()
    opts = if _.isObject args[0] then opts = args.shift() else {}

    # extend options with defaults
    @config = _.defaults opts,
      type: 'whitelist'
      scope: 'username'
      reply: process.env.DENIED_REPLY or "Sorry, I can't do that."

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

    @log.info "New #{ @config.scope } Director #{ @config.type }: #{ @key }"
    if @config.reply?
      @log.info "replies '#{ @config.reply }' if denied"

  # helper used by path, generate key from slugifying or random string
  keygen: (source) ->
    return if source? then slug source else generate 12

  # merge new usernames/rooms with listed names
  add: (names) ->
    @log.info "Adding #{ inspect names } to #{ @key } #{ @config.type }"
    names = [names] if not _.isArray names # cast single as array
    @names = _.union @names, names
    return

  # remove usernames/rooms from listed names
  remove: (names) ->
    @log.info "Removing #{ inspect names } from #{ @key } #{ @config.type }"
    names = [names] if not _.isArray names # cast single as array
    @names = _.without @names, names...
    return

  # let this director control access to a given scene
  directScene: (scene) ->

    # setup middleware to control access to the scene's listeners
    # TODO: setup middleware

    # hook into .enter to control access for manually entered scenes
    hooker.hook scene, 'enter', pre: (res) =>
      if not @canEnter res
        res.reply @config.reply if @config.reply? and @config.reply isnt ''
        return hooker.preempt false

  # determine if user has access, checking against usernames and rooms
  canEnter: (res) ->
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

module.exports = Director

# TODO: save/restore config in hubot brain against key if provided
# TODO: parse Playbook messages for template tags e.g. sorry {{ username }}
