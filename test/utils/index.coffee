# Created by lmarkus on 10/1/15. - Some utils for testing.

module.exports.Messenger = (bot, messages) ->
  next: (cb) ->
    bot.receive messages.shift(), ->
      cb() if typeof callback is 'function'

  sendAll: ->
    messages.forEach (message, idx) ->
      setTimeout ->
        bot.receive message
        return
      , 10 * idx
