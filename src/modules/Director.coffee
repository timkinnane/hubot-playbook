_ = require 'underscore'
hooker = require 'hooker'
{inspect} = require 'util'
{generate} = require 'randomstring'
slug = require 'slug'
{EventEmitter} = require 'events'

# Adds middleware to authorise bot interactions, global or attached to scene
# authMethod can be an adapter method name (string) or a function to call which
# will receive the username, room and full response object to return wether that
# user can access the current scene - e.g. 'hasAdminRole'
# without an authMethod:
# - if a whitelist exists, ONLY those on it are allowed
# - if a blacklist exists, ONLY those on it are denied
# with an authMethod: method can determine access, but lists will overide
# TODO: save/restore black/whitelists in hubot brain against key if provided
class Director extends EventEmitter
  constructor: (@robot, args..., @authMethod) ->

    # take first argument as key if its a string, use leftover args as options
    @key = if _.isString args[0] then @keygen args.shift() else @keygen()
    opts = args[0] or {}

    @log = @robot.logger
    @whitelist = usernames: [], rooms: []
    @blacklist = usernames: [], rooms: []

    # allow setting black/whitelisted usernames and rooms from env var (csv)
    if process.env.WHITELIST_USERS?
      @whitelist.usernames = process.env.WHITELIST_USERS.split ','
    if process.env.WHITELIST_ROOMS?
      @whitelist.rooms = process.env.WHITELIST_ROOMS.split ','
    if process.env.BLACKLIST_USERS?
      @blacklist.usernames = process.env.BLACKLIST_USERS.split ','
    if process.env.BLACKLIST_ROOMS?
      @blacklist.rooms = process.env.BLACKLIST_ROOMS.split ','

    # extend options with defaults
    @config = _.defaults opts,
      deniedResponse: process.env.DENIED_RESPONSE or "Sorry, I can't do that."
      # TODO: parse Playbook messages for template tags e.g. hi {{ username }}

    @log.info """
      New Director #{ @key } responds '#{ @config.deniedResponse }' to denied
    """

  # helper used by path, generate key from slugifying or random string
  keygen: (source) ->
    key = if source? then slug source else generate 12
    return key

  # merge new usernames/rooms with whitelisted (allowed) array
  whitelistAdd: (group, names) ->
    if group not in ['usernames','rooms']
      throw new Error "invalid access group - accepts only usernames, rooms"
    @log.info "Adding #{ inspect names } to #{ @key } whitelist"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.union @whitelist[group], names
    return

  # remove usernames/rooms from whitelisted (allowed) array
  whitelistRemove: (group, names) ->
    if group not in ['usernames','rooms']
      throw new Error "invalid access group - accepts only usernames, rooms"
    @log.info "Removing #{ inspect names } from #{ @key } whitelist"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.without @whitelist[group], names...
    return

  # merge new usernames/rooms with blacklist (denied) array
  blacklistAdd: (group, names) ->
    if group not in ['usernames','rooms']
      throw new Error "invalid access group - accepts only usernames, rooms"
    @log.info "Adding #{ inspect names } to #{ @key } blacklist"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.union @blacklist[group], names
    return

  # remove usernames/rooms from blacklist (denied) array
  blacklistRemove: (group, names) ->
    if group not in ['usernames','rooms']
      throw new Error "invalid access group - accepts only usernames, rooms"
    @log.info "Removing #{ inspect names } from #{ @key } blacklist"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.without @blacklist[group], names...
    return

  # let this director control access to a given scene
  directScene: (scene) ->

    # setup middleware to control access to the scene's listeners
    # TODO: setup middleware

    # hook into .enter to control access for manually entered scenes
    hooker.hook scene, 'enter', pre: (res) =>
      return hooker.preempt false if not @canEnter scene, res

  # determine if user has access, checking against usernames and rooms
  canEnter: (res) ->
    username = res.message.user.name
    room = res.message.room

    # let some through regardless, don't let anyone else through
    if @whitelist.usernames.length
      return true if username in @whitelist.usernames
      return true if room in @whitelist.rooms
      return false if not @authMethod?

    # block some regardless, let anyone else through
    if @blacklist.usernames.length
      return false if username in @blacklist.usernames
      return false if room in @blacklist.room
      return true if not @authMethod?

    # custom method/function will determine access if lists didn't
    if @authMethod?
      if _.isString @authMethod
        return @robot.adapter.callMethod @authMethod, username, room, res
      else if _.isFunction @authMethod
        return @authMethod username, room, res
    return true # no reason not to

module.exports = Director
