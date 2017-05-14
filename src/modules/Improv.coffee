_ = require 'lodash'
Base = require './Base'
Handlebars = require 'handlebars'
HandlebarsIntl = require 'handlebars-intl'
HandlebarsIntl.registerWith Handlebars

###*
 * Merge template tags with contextual content (using handlebars), from app
 * environment, user attributes or manually populated keys.
 * Config:
 * fallback: Fallback content replace any unknowns
 * replacement: Replaces entire messages containing unknowns, overrides fallback
 * locale: Locale for format localisation - yahoo/handlebars-intl
 * formats: Additional named date/time formats
 * @param {Robot}        robot   - Hubot Robot instance
 * @param {Array|String} @admins - Usernames authorised to populate context data
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Improv extends Base
  constructor: (robot, @admins, args...) ->
    @defaults =
      fallback: process.env.IMRPOV_FALLBACK or 'unknown'
      replace: process.env.IMRPOV_REPLACE or null
      locale: process.env.IMRPOV_LOCALE or null
      formats: null
      appData: null

    super 'improv', robot, args...
    @intl.locale = @config.locale if @config.locale?
    @intl.formats = @config.formats if @config.formats?
    robot.responseMiddleware (c, n, d) => @middleware.call @, c, n, d

  ###*
   * Middleware checks for template tags and parses if required
   * @param  {Object}   context - Passed through the middleware stack, with res
   * @param  {Function} next    - Called when all middleware is complete
   * @param  {Function} done    - Initial (final) completion callback
  ###
  middleware: (context, next, done) ->
    if _.anyMatch context.strings, /{{.*}}/
      context.strings = @parse strings, @mergeData context.response.message.user
    next done

  ###*
   * Provdies currnet known user and app data for merging with tempalte
   * @param  {[type]} user [description]
   * @return {[type]}      [description]
  ###
  mergeData: (user) ->
    data = {}
    data.app = _.extend @config.appData, robot.brain.get 'appData'
    data.user = robot.brain.userForId user.id if user?
    return data

  ###*
   * Merge templated messages with data
   * TODO: use fallback/replace for unknowns
   * @param  {Array}  string  - One or more strings being posted
   * @param  {Object} data    - Key/vals for template tags (app and/or user)
   * @return {Array}          - Strings populated with context values
  ###
  parse: (strings, data) ->
    return _.map strings (string) ->
      template = Handlebars.compile string
      return template data, data: intl: @intl if @intl?
      return template data

  # TODO: look through array of messages for unknowns
  prepare: (strings) ->

  # TODO: ask admins to provide context for any unknowns
  warn: (unknowns) ->

  # TODO: add data to context
  remember: (key, content) ->

  # TODO: remove data from context
  forget: (key) ->
