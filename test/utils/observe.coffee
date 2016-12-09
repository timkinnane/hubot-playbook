_ = require 'underscore'
require('underscore-observe')(_) # extends underscore

module.exports.observer = () ->

  # look for any new message
  next: (messages, cb) ->
    start = messages.length
    _.observe messages, 'create', (created) ->
      if messages.length > start
        _.unobserve()
        cb created

  # look for a specific message
  when: (messages, message, cb) ->
    _.observe messages, 'create', (created)->
      if message is created
        _.unobserve()
        cb created

  # look at every message
  all: (messages, cb) -> _.observe messages, 'create', -> cb() # every time

  # stop looking at all
  stop: -> _.unobserve() # alias for consistent syntax
