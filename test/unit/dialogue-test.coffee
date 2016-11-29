Q = require 'q'
mute = require 'mute'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

{Robot, TextMessage, User} = require 'hubot'
{EventEmitter} = require 'events'
Helper = require 'hubot-test-helper'
module = "../../src/modules/Dialogue"
script = "#{ module }.coffee"
helper = new Helper script
Dialogue = require module
_ = require 'underscore'
Timeout = setTimeout () ->
  null
, 0
.constructor # get the null Timeout prototype instance for comparison

# prevent environment changing tests
delete process.env.DIALOGUE_TIMEOUT
delete process.env.DIALOGUE_TIMEOUT_LINE

# Tests for user-to-bot / group-to-bot dialogues

describe '#Dialogue', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @user = new User 'Tester', room: 'Lobby'
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @res = null
    @bot.respond /testing/, (res) => @res = res
    @bot.receive new TextMessage @user, 'Hubot testing', '111'
    @spy =
      startTimeout: sinon.spy Dialogue.prototype, 'startTimeout'
      onTimeout: sinon.spy Dialogue.prototype, 'onTimeout'
      receive: sinon.spy Dialogue.prototype, 'receive'
      send: sinon.spy Dialogue.prototype, 'send'
      complete: sinon.spy Dialogue.prototype, 'complete'
      choice: sinon.spy Dialogue.prototype, 'choice'
      getChoices: sinon.spy Dialogue.prototype, 'getChoices'
      clearChoices: sinon.spy Dialogue.prototype, 'clearChoices'

  afterEach ->
    @bot.shutdown()
    _.invoke @spy, 'restore' # remove spies so they can be reattached clean

  context 'Create a Dialogue with defaults', ->

    beforeEach (done) ->
      Q.delay(200).done =>
        @dialogue = new Dialogue @res
        done()

    afterEach -> clearTimeout @dialogue.countdown

    it 'inherits event emmiter', ->
      @dialogue.should.be.instanceof EventEmitter
      @dialogue.emit.should.be.instanceof Function

    it 'has the logger from response object robot', ->
      @dialogue.logger.should.eql @bot.logger

    it 'has an empty choices array', ->
      @dialogue.choices.should.be.an 'Array'
      @dialogue.choices.length.should.equal 0

    it 'has config with defaults', ->
      @dialogue.config.should.be.an 'Object'
      @dialogue.config.timeout.isNumber
      @dialogue.config.timeout.should.equal 30000
      @dialogue.config.timeoutLine.should.equal 'Timed out! Please start again.'

    it 'starts timeout', ->
      @dialogue.countdown.should.exist
      @dialogue.countdown.should.be.instanceof Timeout
      @spy.startTimeout.should.have.been.calledOnce

  context 'Create a Dialogue with env vars', ->

    beforeEach (done) ->
      process.env.DIALOGUE_TIMEOUT = 500
      process.env.DIALOGUE_TIMEOUT_LINE = 'Testing timeout'
      Q.delay(200).done =>
        @dialogue = new Dialogue @res
        done()

    afterEach -> clearTimeout @dialogue.countdown

    it 'uses the environment timeout settings', ->
      @dialogue.config.timeout.should.equal 500
      @dialogue.config.timeoutLine.should.equal 'Testing timeout'
