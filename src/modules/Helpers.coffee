_ = require 'underscore'
slug = require 'slug'

module.exports =

  # get a unique key for a defined context (scope), randomly if not given source
  # @param scope {String} namespace for identifying key usage
  # @param source {String} (optional) to be "slugified" into a safe key string
  keygen: (scope, source) ->
    throw new Error "Key requires a scope param" if not (scope? or source?)
    scope = "#{scope}_#{source}" if scope? and source? # join namespaces
    return _.uniqueId "#{ slug scope }_"
