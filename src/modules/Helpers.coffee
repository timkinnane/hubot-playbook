{generate} = require 'randomstring'
slug = require 'slug'

ids = [] # list of used id strings to avoid dupes

# helpers used by various Playbook modules
module.exports =

  # return key from slugifying source string or generated random
  keygen: (source) ->
    if source?
      return slug source if slug source not in keys
      throw new Error "Key already exists for #{ slug source }"
    else
      random = generate 8 while random not in keys
      return random
