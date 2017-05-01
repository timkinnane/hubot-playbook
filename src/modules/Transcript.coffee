_ = require 'lodash'
Base = require './Base'

class Transcript extends Base
  constructor: (robot, matchKey, opts) ->
    @defaults =
      save: true
      types: ['match', 'mismatch', 'catch', 'send']

    super 'transcript', robot, opts
    @records = @robot.brain.get 'transcripts' if @config.save
    @records ?= []

    _.each @config.types, (type) =>
      @robot.on type, (args...) => @record type, args...

  record: (type, ID, res, args...) ->
    console.log instanceID, args[0]
    record =
      time: now()
      type: event
      username: res.user.name
      message: res.message.text

  TODO: CHANGE IDs to split parts, maybe call it .meta?
  ID =
    unique: xxx
    type: 'scene'
    slug: 'safe-key'

  #
  # ###*
  #  * TODO: refactor with current emit args as method of transcript module
  #  * Emit event and add to transcript if currently executing a named path
  #  * @param  {String} type    - Event type in context: send|match|mismatch
  #  * @param  {User}   user    - Hubot User object
  #  * @param  {String} text    - Message text
  #  * @param  {Array} [match]  - Match results
  #  * @param  {RegExp} [regex] - Matching expression
  # ###
  # record: (type, user, text, match, regex) ->
  #   @paths[@pathId].transcript.push [ type, user, text ] if @pathId?
  #   switch type
  #     when 'match'
  #       @log.debug "Received \"#{ text }\" matched #{ regex }"
  #       @emit 'match', user, text, match, regex
  #     when 'mismatch'
  #       @log.debug "Received \"#{ text }\" matched nothing"
  #       @emit 'mismatch', user, text
  #     when 'send'
  #       @log.debug "Sent \"#{ text }\""
  #   return

module.exports = Transcript
