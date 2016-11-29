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
    # console.log @res
    @logger = @res.robot.logger
    @choices = []
    @config = _.defaults options, # use defaults for any missing options
      timeout: parseInt process.env.DIALOGUE_TIMEOUT or 30000
      timeoutLine: process.env.DIALOGUE_TIMEOUT_LINE or
        'Timed out! Please start again.'
    @startTimeout()

  startTimeout: ->
    @countdown = setTimeout () =>
      @emit 'timeout', @res
      @onTimeout @res
    , @config.timeout

  clearTimeout: -> clearTimeout @countdown

  # default timeout method sends line unless null or method overrride
  onTimeout: -> @send @res, @config.timeoutLine if @config.timeoutLine?

  # accept an incoming message, match against the registered choices
  # if matched, deliver response, clear timeout and end dialogue
  # @param res, the message object to match against
  receive: (res) ->
    line = res.message.text
    @logger.debug "Dialogue received "
    match = false

    # stop at the first match in the order in which they were added
    @choices.some (choice) =>
      if match = line.match choice.regex
        @logger.debug "`#{ line }` matched #{ inspect choice.regex }"
        @emit 'match', line, choice.regex

        # match found, clear this step
        @clearChoices()
        @clearTimeout()

        res.match = match # overrride the original match from hubot listener
        choice.handler(res) # may add additional choices
        return true

    # complete fail if nothing matched, success if nothing left to do
    return @complete false unless match
    return @complete true if @choices.length is 0

  # address the audience appropriately
  send: (res, line) -> if @config.reply then res.reply line else res.send line

  # send status for scene to disengage participants
  complete: (success) ->
    @logger.debug "Dialog #{ if success then 'succeeded' else 'failed' }"
    @emit 'complete', @res, success
    @clearTimeout()
    return success

  # add a choice branch with string response and/or callback
  # 1: .choice( regex, response ) reply with response on regex match
  # 2: .choice( regex, callback ) trigger callback on regex match
  # 3: .choice( regex, response, callback ) reply and do callback
  # @param regex, expression to match
  # @param {string} response message text (optional)
  # @param {function} handler function when matched (optional)
  choice: (regex, args...) ->
    if typeof args[0] is 'function'
      handler = args[0]
    else if typeof args[0] is 'string'
      handler = (res) =>
        @send res, args[0]
        args[1] res if typeof args[1] is 'function'
    else
      @logger.error 'wrong args given for choice'
      return false

    # new choice restarts the countdown
    @clearTimeout()
    @startTimeout()
    @choices.push # return new choices length
      regex: regex,
      handler: handler

  getChoices: -> @choices

  clearChoices: -> @choices = []

module.exports = Dialogue
