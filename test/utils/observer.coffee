Q = require 'q'
_ = require 'underscore'
require('underscore-observe')(_) # extends underscore

module.exports = class Observer
  constructor: (@messages) ->

  # look for any new message (resolve promise when found)
  next: ->
    deferred = Q.defer()
    start = @messages.length
    _.observe @messages, 'create', (created) =>
      if @messages.length > start
        _.unobserve()
        deferred.resolve created
    deferred.promise

  # look for a specific message (resolve promise when found)
  when: (message) ->
    deferred = Q.defer()
    _.observe @messages, 'create', (created) =>
      if message is created
        _.unobserve()
        deferred.resolve created
    deferred.promise

  # run callback with every @messages
  all: (cb) -> _.observe @messages, 'create', -> cb() # every time

  # stop looking at all (alias for consistent syntax)
  stop: -> _.unobserve()
