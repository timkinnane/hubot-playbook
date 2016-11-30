Q = require 'q'
_ = require 'underscore'
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
  beforeEach (done) ->
    @user = new User 'Tester', room: 'Lobby'
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @res = null
    @bot.respond /testing/, (res) => @res = res
    @bot.receive new TextMessage @user, 'Hubot testing', '111' # start dialogue
    @spy =
      startTimeout: sinon.spy Dialogue.prototype, 'startTimeout'
      onTimeout: sinon.spy Dialogue.prototype, 'onTimeout'
      receive: sinon.spy Dialogue.prototype, 'receive'
      send: sinon.spy Dialogue.prototype, 'send'
      complete: sinon.spy Dialogue.prototype, 'complete'
      choice: sinon.spy Dialogue.prototype, 'choice'
      getChoices: sinon.spy Dialogue.prototype, 'getChoices'
      clearChoices: sinon.spy Dialogue.prototype, 'clearChoices'
    Q.delay(100).done -> done() # let it process the messages and create res

  afterEach ->
    _.invoke @spy, 'restore'
    @bot.shutdown()

  context 'Create a Dialogue with defaults', ->

    beforeEach -> @dialogue = new Dialogue @res
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

    beforeEach ->
      # unmute = mute()
      process.env.DIALOGUE_TIMEOUT = 500
      process.env.DIALOGUE_TIMEOUT_LINE = 'Testing timeout env'
      @dialogue = new Dialogue @res
    afterEach ->
      clearTimeout @dialogue.countdown
      delete process.env.DIALOGUE_TIMEOUT
      delete process.env.DIALOGUE_TIMEOUT_LINE
      # unmute()

    it 'uses the environment timeout settings', ->
      @dialogue.config.timeout.should.equal 500
      @dialogue.config.timeoutLine.should.equal 'Testing timeout env'

  context 'Create a Dialogue with options', ->

    beforeEach ->
      @dialogue = new Dialogue @res,
        timeout: 555
        timeoutLine: 'Testing timeout options'
    afterEach -> clearTimeout @dialogue.countdown

    it 'uses the passed options timeout settings', ->
      @dialogue.config.timeout.should.equal 555
      @dialogue.config.timeoutLine.should.equal 'Testing timeout options'

  context 'Create a Dialogue with 100ms timeout', ->

    beforeEach (done) ->
      unmute = mute()
      @eventSpy = sinon.spy()
      @dialogue = new Dialogue @res,
        timeout: 100
      @dialogue.on 'timeout', @eventSpy
      Q.delay(110).done ->
        unmute()
        done()
    afterEach -> clearTimeout @dialogue.countdown

    it 'emits timeout event', ->
      @eventSpy.should.have.been.calledOnce

    it 'calls onTimeout', ->
      @spy.onTimeout.should.have.been.calledOnce
