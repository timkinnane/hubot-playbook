_ = require 'underscore'
{inspect} = require 'util'
{EventEmitter} = require 'events'

# Adds middleware to authorise bot interactions, global or attached to scene
class Director extends EventEmitter
  constructor: (@robot, opts={}) ->
    @log = @robot.logger
    @allowed =
      users: []
      roles: []
      rooms: []
    @denied =
      users: []
      roles: []
      rooms: []

    # extend options with defaults
    @config = _.defaults opts,
      denyResponse: process.env.DENY_RESPONSE or "Sorry, I can't do that."
      # TODO: parse Playbook messages for template tags e.g. hi {{ username }}

  # merge new usernames with allowed users array
  allowUsers: (usernames) ->
    usernames = [usernames] if not _.isArray usernames # cast single as array
    @allowed.users = _.union @allowed.users, usernames
    return

  # merge new usernames with denied users array
  denyUsers: (usernames) ->
    usernames = [usernames] if not _.isArray usernames # cast single as array
    @denied.users = _.union @denied.users, usernames
    return

  # merge new roles with allowed roles array
  allowRoles: (rolenames) ->
    rolenames = [rolenames] if not _.isArray rolenames # cast single as array
    @allowed.roles = _.union @allowed.roles, rolenames
    return

  # merge new roles with denied roles array
  denyRoles: (rolenames) ->
    rolenames = [rolenames] if not _.isArray rolenames # cast single as array
    @denied.roles = _.union @denied.roles, rolenames
    return

  # merge new rooms with allowed rooms array
  allowRooms: (roomnames) ->
    roomnames = [roomnames] if not _.isArray roomnames # cast single as array
    @allowed.roles = _.union @allowed.roles, roomnames
    return

  # merge new rooms with denied rooms array
  denyRooms: (roomnames) ->
    roomnames = [roomnames] if not _.isArray roomnames # cast single as array
    @denied.roles = _.union @denied.roles, roomnames
    return

  # let this director control access to a given scene
  directScene: (scene) ->

  # determine if user has access, checking against names, roles and rooms
  canEnter: (user) ->
