_ = require 'lodash'
Base = require './Base'
icu = require 'full-icu'
Handlebars = require 'handlebars'
HandlebarsIntl = require 'handlebars-intl'
HandlebarsIntl.registerWith Handlebars

###*
 * Merge template tags with contextual content (using handlebars), from app
 * environment, user attributes or manually populated keys.
 * Improv uses singleton pattern, all replacements are handled by one module
 * TODO: support fallback/replacement and locale/formats
 * Config keys:
 * - save: keep app context in hubot brain
 * - fallback: Fallback content replace any unknowns within messages
 * - replacement: Replaces all messages containing unknowns, overrides fallback
 * - locale: Locale for format internationalization - yahoo/handlebars-intl
 * - formats: Additional named date/time formats
 * - app: Data object with app context attributes to merge into tempaltes
 * - admins: Array of usernames authorised to populate context data
###

class ImprovSingleton
  instance = null

  class ImprovPrivate extends Base

    ###*
     * Create new private Improv class - returned by singleton
     * Resets config
     * @param {Robot}  robot     - Hubot Robot instance
     * @param {Object} [options] - Key/val options for config
     * @param {String} [key]     - Key name for this instance
    ###
    constructor: (args...) ->
      @init()
      super 'improv', args...
      @use @robot

      #TODO: Test on Playbook demo and node built in Docker --with-full-icu
      @icu = icu
      @icuInfo = if icu.icu_small then "english only" else "international"
      @log.debug "Improv loaded, has ICU for locale translation: #{ @hasICU }"

    ###*
     * Start with fresh settings, possibly after config changed
    ###
    init: ->
      @config =
        save: true
        fallback: process.env.IMRPOV_FALLBACK or 'unknown'
        replace: process.env.IMRPOV_REPLACE or null
        locale: process.env.IMRPOV_LOCALE or 'en'
        formats: {}
        data: {}
      @extensions = []
      return

    ###*
     * Use a robot and get data from the brain - modular for testing with resets
     * @param  {Robot} robot The robot to use, usually existing from constructor
     * @return {Self} - The instance for chaining
    ###
    use: (robot) ->
      unless _.isEqual robot, @robot
        @robot = robot
        @robot.brain.set 'improv', {} unless @robot.brain.get 'improv'
        @robot.responseMiddleware (c, n, d) => @middleware.call @, c, n, d
      return @

    ###*
     * Allows adding extra functions to provide further context
     * e.g. extend merge data with user transcript history...
     * improv.extend (data) ->
     *  transcript.findRecords message: user: id: data.user.id
     * @param  {Function} dataFunc - Receives merge data, to more return data
     * @return {Self} - The instance for chaining
    ###
    extend: (dataFunc) ->
      @extensions.push dataFunc if _.isFunction dataFunc
      return @

    ###*
     * Provdies current known user and app data for merging with tempalte
     * Runs any extension functions, e.g. to merge data from other sources
     * TODO: allow tagging other user's data by merge with robot.brain.userForId
     * @param  {Object} user - User (usually from middleware context)
     * @return {Object}      - App and user (from brain) data, with any extras
    ###
    mergeData: (user) ->
      dataSources = [@config.data, user: user]
      dataSources.push @robot.brain.get 'improv' if @config.save
      data = _.defaultsDeep dataSources...
      return _.reduce @extensions, (merge, func) ->
        _.defaultsDeep merge, func merge
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
        data = intl: formats: @config.formats
        data.intl.locale = @config.locale if @hasICU
        return template context, data: data

    ###*
     * Middleware checks for template tags and parses if required
     * @param  {Object}   context - Passed through middleware stack, with res
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

    # TODO: ask configured admins to provide context for any unknowns
    warn: (unknowns) ->

    # TODO: add data to context
    remember: (key, content) ->

    # TODO: remove data from context
    forget: (key) ->

    ###*
     * Shutdown and re-initialise instance (mostly for tests)
     * @return {Self} - The reset instance
    ###
    reset: ->
      @init()
      return @

  ###*
   * Static method either updates existing or creates new Improv
   * Only attaches robot first time, but uses extra args to reconfigure if given
   * @return {Improv} - New or existing instance
  ###
  @get: (robot, args...) ->
    unless instance?
      instance = new ImprovPrivate robot, args...
    else
      instance.configure args... if args.length
      instance.use robot unless _.isEqual robot, instance.robot
    return instance

module.exports = ImprovSingleton
