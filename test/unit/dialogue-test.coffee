Q = require 'q'
_ = require 'underscore'
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

  context 'Create a Dialogue with defaults', ->

    beforeEach -> @dialogue = new Dialogue @res
    afterEach -> clearTimeout @dialogue.countdown

    it 'inherits event emmiter', ->
      @dialogue.should.be.instanceof EventEmitter
      @dialogue.emit.should.be.instanceof Function

    it 'has the logger from response object robot', ->
      @dialogue.logger.should.eql @room.robot.logger

    it 'has an empty choices array', ->
      @dialogue.choices.should.be.an 'Array'
      @dialogue.choices.length.should.equal 0

    it 'has config with defaults of correct type', ->
      @dialogue.config.isObject
      @dialogue.config.timeout.isNumber
      @dialogue.config.timeoutLine.isString

    it 'starts timeout', ->
      @dialogue.countdown.should.exist
      @dialogue.countdown.should.be.instanceof Timeout
      @spy.startTimeout.should.have.been.calledOnce

  context 'Create a Dialogue with env vars', ->

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
