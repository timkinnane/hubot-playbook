_ = require 'underscore'
{inspect} = require 'util'
{generate} = require 'randomstring'
slug = require 'slug'
{EventEmitter} = require 'events'

# Adds middleware to authorise bot interactions, global or attached to scene
class Director extends EventEmitter
  constructor: (@robot, args...) ->

    # take first argument as key if its a string, use leftover args as options
    @key = if _.isString args[0] then @keygen args.shift() else @keygen()
    opts = args[0] or {}

    @log = @robot.logger
    @whitelist = users: [], roles: [], rooms: []
    @blacklist = users: [], roles: [], rooms: []

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

  # merge new usernames/roles/rooms with whitelisted (allowed) array
  whitelistAdd: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    @log.info "Adding #{ inspect names } to #{ @key } whitelist"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.union @whitelist[group], names
    return

  # remove usernames/roles/rooms from whitelisted (allowed) array
  whitelistRemove: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    @log.info "Removing #{ inspect names } from #{ @key } whitelist"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.without @whitelist[group], names...
    return

  # merge new usernames/roles/rooms with blacklist (denied) array
  blacklistAdd: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    @log.info "Adding #{ inspect names } to #{ @key } blacklist"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.union @blacklist[group], names
    return

  # remove usernames/roles/rooms from blacklist (denied) array
  blacklistRemove: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    @log.info "Removing #{ inspect names } from #{ @key } blacklist"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.without @blacklist[group], names...
    return

  # let this director control access to a given scene
  directScene: (scene) ->

  # determine if user has access, checking against names, roles and rooms
  canEnter: (scene, user) ->
    # TODO:
    #   - if whitelist exists, only those on it can access
    #   - if blacklist exists, anyone not on it can access

module.exports = Director
