_ = require 'underscore'
{inspect} = require 'util'
{EventEmitter} = require 'events'

# Adds middleware to authorise bot interactions, global or attached to scene
class Director extends EventEmitter
  constructor: (@robot, opts={}) ->
    @log = @robot.logger
    @whitelist = users: [], roles: [], rooms: []
    @blacklist = users: [], roles: [], rooms: []

    # extend options with defaults
    @config = _.defaults opts,
      deniedResponse: process.env.DENIED_RESPONSE or "Sorry, I can't do that."
      # TODO: parse Playbook messages for template tags e.g. hi {{ username }}

  # merge new usernames/roles/rooms with whitelisted (allowed) array
  whitelistAdd: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.union @whitelist[group], names
    return

  # remove usernames/roles/rooms from whitelisted (allowed) array
  whitelistRemove: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    names = [names] if not _.isArray names # cast single as array
    @whitelist[group] = _.union @whitelist[group], names
    return

  # merge new usernames/roles/rooms with blacklist (denied) array
  blacklistAdd: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.union @blacklist[group], names
    return

  # remove usernames/roles/rooms from blacklist (denied) array
  blacklistRemove: (group, names) ->
    if group not in ['users','roles','rooms']
      throw new Error "invalid access group - accepts only users, roles, rooms"
    names = [names] if not _.isArray names # cast single as array
    @blacklist[group] = _.union @blacklist[group], names
    return

  # let this director control access to a given scene
  directScene: (scene) ->

  # determine if user has access, checking against names, roles and rooms
  canEnter: (scene, user) ->
    # TODO:
    #   - if whitelist exists, only those on it can access
    #   - if blacklist exists, anyone not on it can access

module.exports = Director
