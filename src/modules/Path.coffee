_ = require 'lodash'
Base = require './Base'

###*
 * Path usually with one or more branches to follow upon matching input
 * Path is opened when branches added, closed when branch is matched
 * Branches may also be added after constructor and by callbacks on a match
 * @param  {Robot} robot       - Hubot Robot instance
 * @param  {Array} [branches]  - Arguments for each brancch, each containing:
 *                               - regex for listener
 *                               - string for sending on match OR
 *                               - callback to fire on match
 * @param  {Object} [opts]     - Config key/vals
 * TODO: add catch-all handler for mismatch replies in context with options
 *       *would not close path
###
class Path extends Base
  constructor: (robot, branches, opts) ->
    super 'path', robot, opts
    @branches = []
    @closed = true # no branches yet, default to closed
    if branches?
      @error "Branches must be Array" unless _.isArray branches
      branches = [branches] unless _.isArray branches[0] # cast 2D array
      _.forEach branches, (branch) => @addBranch branch...

  ###*
   * Add a branch (matching expression and handler) for optional dialogue input
   * On match, handler either fires callback, sends a message or both
   * @param {RegExp}   regex      - Matching pattern
   * @param {String}   [message]  - Message text for response on match
   * @param {Function} [callback] - Function called when matched
  ###
  addBranch: (regex, args...) ->
    @error 'Invalid RegExp for branch' unless _.isRegExp regex
    message = args.shift() if _.isString args[0]
    callback = args.shift() if _.isFunction args[0]
    @error "Missing args for branch" unless message? or callback?
    @branches.push regex: regex, handler: (res, dialogue) ->
      dialogue.send message if message?
      callback res, dialogue if callback?
    @closed = false # path is open as long as branches are added
    return

  ###*
   * Attempt to match an incoming response object
   * Overrides the original match (catch-all from dialogue listener) in response
   * Even if not matched, still overrides as a null match for further processes
   * Matching closes the path, but the handler may add branches, re-opening it
   * @param  {Response} res     - Hubot Response object
   * @return {Object|undefined} - Matched branch with regex and handler
  ###
  match: (res) ->
    text = res.message.text
    branch = _.find @branches, (branch) ->
      res.match = text.match branch.regex
      return res.match # truthy / falsey
    @closed = true if branch?
    return branch

module.exports = Path
