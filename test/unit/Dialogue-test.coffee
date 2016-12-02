Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/noScript.coffee"
Dialogue = require "../../src/modules/Dialogue"
{EventEmitter} = require 'events'
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
    @room = helper.createRoom()
    @res = null
    @room.robot.respond /testing/, (res) => @res = res
    @room.user.say 'user1', 'hubot testing' # start dialogue
    @spy = _.mapObject Dialogue.prototype, (val, key) ->
      sinon.spy Dialogue.prototype, key # spy on all the class methods
    Q.delay(100).done -> done() # let it process the messages and create res

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'Dialogue created with defaults', ->

    beforeEach -> @dialogue = new Dialogue @res
    afterEach -> clearTimeout @dialogue.countdown

    it 'inherits event emmiter', ->
      @dialogue.should.be.instanceof EventEmitter
      @dialogue.emit.should.be.a 'function'

    it 'has the logger from response object robot', ->
      @dialogue.logger.should.eql @room.robot.logger

    it 'has an empty choices array', ->
      @dialogue.choices.should.be.an 'array'
      @dialogue.choices.length.should.equal 0

    it 'has config with defaults of correct type', ->
      @dialogue.config.should.be.an 'object'
      @dialogue.config.timeout.should.be.a 'number'
      @dialogue.config.timeoutLine.should.be.a 'string'

    it 'starts timeout', ->
      @dialogue.countdown.should.exist
      @dialogue.countdown.should.be.instanceof Timeout
      @spy.startTimeout.should.have.been.calledOnce

  context 'Dialogue created with env vars', ->

    beforeEach ->
      process.env.DIALOGUE_TIMEOUT = 500
      process.env.DIALOGUE_TIMEOUT_LINE = 'Testing timeout env'
      @dialogue = new Dialogue @res
    afterEach ->
      clearTimeout @dialogue.countdown
      delete process.env.DIALOGUE_TIMEOUT
      delete process.env.DIALOGUE_TIMEOUT_LINE

    it 'uses the environment timeout settings', ->
      @dialogue.config.timeout.should.equal 500
      @dialogue.config.timeoutLine.should.equal 'Testing timeout env'

  context 'Dialogue created with options', ->

    beforeEach ->
      @dialogue = new Dialogue @res,
        timeout: 555
        timeoutLine: 'Testing timeout options'
    afterEach -> clearTimeout @dialogue.countdown

    it 'uses the passed options timeout settings', ->
      @dialogue.config.timeout.should.equal 555
      @dialogue.config.timeoutLine.should.equal 'Testing timeout options'

  context 'Dialogue created with 100ms timeout', ->

    beforeEach (done) ->
      @eventSpy = sinon.spy()
      @dialogue = new Dialogue @res, timeout: 100
      @dialogue.on 'timeout', @eventSpy
      Q.delay(110).done -> done()
    afterEach -> clearTimeout @dialogue.countdown

    it 'emits timeout event', ->
      @eventSpy.should.have.been.calledOnce

    it 'calls onTimeout', ->
      @spy.onTimeout.should.have.been.calledOnce

    it 'sends timout message to room', ->
      @room.messages.should.eql [
        [ 'user1', 'hubot testing' ],
        [ 'hubot', @dialogue.config.timeoutLine ]
      ]

  context 'Dialogue created with different choice types', ->

    beforeEach (done) ->
      unmute = mute() # don't write logs amongst test results
      @dialogue = new Dialogue @res, timeout: 500
      @errSpy = sinon.spy @room.robot.logger, 'error'
      @cbSpy1 = sinon.spy()
      @cbSpy2 = sinon.spy()
      @dialogue.choice /number 1/i, 'Nothing'
      @dialogue.choice /number 2/i, @cbSpy1
      @dialogue.choice /number 3/i, 'Booby Prize', @cbSpy2
      @dialogue.choice /number 4/i, null
      unmute()
      Q.delay(100).done -> done()
    afterEach -> clearTimeout @dialogue.countdown

    it 'Should clear and restart the timeout each time', ->
      @spy.clearTimeout.should.have.been.calledThrice

    it 'Should remember three (of four) valid choices', ->
      @dialogue.choices.should.be.an 'array'
      @dialogue.choices.length.should.equal 3

    it 'Should create an object with a listener and a handler for each', ->
      _.each @dialogue.choices, (choice) =>
        choice.should.be.an 'object'
        choice.regex.should.be.instanceof RegExp
        choice.handler.should.be.a 'function'

    it 'Should have logged an error for incorrect args', ->
      @errSpy.should.have.been.calledOnce
