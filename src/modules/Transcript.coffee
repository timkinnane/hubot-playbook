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
