_ = require 'lodash'
Base = require './Base'
Handlebars = require 'handlebars'
HandlebarsIntl = require 'handlebars-intl'
HandlebarsIntl.registerWith Handlebars

###*
 * Merge template tags with contextual content (using handlebars), from app
 * environment, user attributes or manually populated keys.
 * TODO: support fallback/replacement and locale/formats
 * Config keys:
 * - save: keep app context in hubot brain
 * - fallback: Fallback content replace any unknowns within messages
 * - replacement: Replaces all messages containing unknowns, overrides fallback
 * - locale: Locale for format internationalization - yahoo/handlebars-intl
 * - formats: Additional named date/time formats
 * @param {Robot}  robot     - Hubot Robot instance
 * @param {Array}  [admins]  - Usernames authorised to populate context data
 * @param {Object} [options] - Key/val options for config
 * @param {String} [key]     - Key name for this instance
###
class Improv extends Base
  constructor: (robot, args...) ->
    @defaults =
      save: true
      fallback: process.env.IMRPOV_FALLBACK or 'unknown'
      replace: process.env.IMRPOV_REPLACE or null
      locale: process.env.IMRPOV_LOCALE or 'en'
      formats: {}
      app: {}
    @admins = if _.isArray args[0] then args.shift() else []
    @extensions = []

    super 'improv', robot, args...
    if @config.save
      @robot.brain.set 'app', {} unless @robot.brain.get 'app'
      @appData = _.defaultsDeep @config.app, @robot.brain.get 'app'
    else
      @appData = @config.app

    robot.responseMiddleware (c, n, d) => @middleware.call @, c, n, d

  ###*
   * Allows adding extra functions to provide further context
   * e.g. extend merge data with user transcript history...
   * improv.extend (data) ->
   *  transcript.findRecords message: user: id: data.user.id
   * @param  {Function} dataFunc - Receives merge data, to more return data
  ###
  extendData: (dataFunc) ->
    return @extensions.push dataFunc if _.isFunction dataFunc

  ###*
   * Provdies current known user and app data for merging with tempalte
   * TODO: allow tagging another users data by merge with robot.brain.userForId
   * @param  {Object} user - User (usually from middleware context)
   * @return {Object}      - App and user (from brain) data, with any extras
  ###
  mergeData: (user) ->
    data =
      user: name: user.name, id: user.id
      app: @appData
    return _.reduce @extensions, (merge, dataFunc) ->
      _.defaultsDeep merge, dataFunc merge
    , data

  ###*
   * Merge templated messages with data (replace unknowns as configured)
   * @param  {Array}  string  - One or more strings being posted
   * @param  {Object} context - Key/vals for template tags (app and/or user)
   * @return {Array}          - Strings populated with context values
   * TODO: use fallback/replace for unknowns
  ###
  parse: (strings, context) ->
    return _.map strings, (string) =>
      template = Handlebars.compile string
      return template context, data: intl:
        locales: @config.locale
        formats: @config.formats

  ###*
   * Middleware checks for template tags and parses if required
   * @param  {Object}   context - Passed through the middleware stack, with res
   * @param  {Function} next    - Called when all middleware is complete
   * @param  {Function} done    - Initial (final) completion callback
  ###
  middleware: (context, next, done) ->
    hasTag = _.some context.strings, (str) -> str.match /{{.*}}/
    if hasTag
      data = @mergeData context.response.message.user
      context.strings = @parse context.strings, data
    next done

  # TODO: look through array of messages for unknowns
  prepare: (strings) ->

  # TODO: ask admins to provide context for any unknowns
  warn: (unknowns) ->

  # TODO: add data to context
  remember: (key, content) ->

  # TODO: remove data from context
  forget: (key) ->

module.exports = Improv
