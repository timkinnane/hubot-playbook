# credit to lmarkus/hubot-conversation for the original concept

_ = require 'underscore'
{inspect} = require 'util'
{EventEmitter} = require 'events'

# multiple-choice dialogue interactions
# the timeout will trigger a timeout message if nothing matches in time
# @param res, incoming message initiating dialogue
# @param {object} options key/vals for config, e.g overide timeout default
class Dialogue extends EventEmitter
  constructor: (@res, options={}) ->
    @logger = @res.robot.logger
    @choices = []
    @ended = false
    @config = _.defaults options, # use defaults for any missing options
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutLine: process.env.DIALOGUE_TIMEOUT_LINE or
        'Timed out! Please start again.'

  startTimeout: ->
    @countdown = setTimeout () =>
      @emit 'timeout'
  #try @onTimeout() catch e then @logger.error "onTimeout error: #{ inspect e}"
      @onTimeout()
      delete @countdown
      @end()
    , @config.timeout

  clearTimeout: ->
    clearTimeout @countdown
    delete @countdown

  # default timeout method sends line unless null or method overriden
  # can override by passing in a function, or reassigning the property
  onTimeout: (override) ->
    if override?
      @onTimeout = override
    else
      @send @config.timeoutLine if @config.timeoutLine?

  # add a choice branch with string response and/or callback
  # 1: .choice( regex, response ) reply with response on regex match
  # 2: .choice( regex, callback ) trigger callback on regex match
  # 3: .choice( regex, response, callback ) reply and do callback
  # @param regex, expression to match
  # @param {string} response message text (optional)
  # @param {function} handler function when matched (optional)
  choice: (regex, args...) ->

    # validate arguments
    if not _.isRegExp regex
      @logger.error 'invalid regex given for choice'
      return false
    if typeof args[0] is 'function'
      handler = args[0]
    else if typeof args[0] is 'string'
      handler = (res) =>
        @send args[0]
        args[1] res if typeof args[1] is 'function'
    else
      @logger.error 'wrong args given for choice'
      return false

    # new choice restarts the countdown
    @clearTimeout() if @countdown?
    @startTimeout()
    @choices.push # return new choices length
      regex: regex,
      handler: handler

  clearChoices: -> @choices = []

  # accept an incoming message, match against the registered choices
  # if matched, deliver response, restart timeout and end dialogue
  # @param res, the message object to match against
  receive: (res) ->
    return false if @ended # dialogue is over, don't process

    line = res.message.text
    @logger.debug "Dialogue received #{ line }"
    match = false

    # stop at the first match in the order in which they were added
    @choices.some (choice) =>
      if match = line.match choice.regex
        @logger.debug "`#{ line }` matched #{ inspect choice.regex }"
        @emit 'match', res.message.user, line, match, choice.regex

        # match found, clear this step
        @clearChoices()
        @clearTimeout()

        res.match = match # override the original match from hubot listener
        choice.handler res # may add additional choices / restarting timeout
        return true # don't process further matches

    # report if nothing matched
    @emit 'mismatch', res.message.user, line if not match

    # end if nothing left to do
    @end() if @choices.length is 0

  # Send response using original response object
  # Address the audience appropriately (i.e. @user reply or send to channel)
  send: (line) -> if @config.reply then @res.reply line else @res.send line

  # shut it down - emit status for scene to disengage participants
  end: ->
    return false if @ended
    complete = @choices.length is 0
    @logger.debug "Dialog ended #{ if not complete then 'in' }complete"
    @clearTimeout() if @countdown?
    @emit 'end', complete
    @ended = true

module.exports = Dialogue

# TODO: Refactor choice as (path>branch/prompt) store prior message as prompt
# Accept key name for path, or generate unique ID
# Keep history of key and corresponding branch match
# Path contains the message "prompt" that preceed choices and each "branch"
# Each choice answered, resets the current path
# Debounce or queue consquetive receive calls to process messages synchronously
