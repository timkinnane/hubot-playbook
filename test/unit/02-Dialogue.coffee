Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/ping.coffee"
observer = require '../utils/observer'
Dialogue = require "../../src/modules/Dialogue"
{TextMessage, User, Response} = require 'hubot'
{EventEmitter} = require 'events'
Timeout = setTimeout () ->
  null
, 0
.constructor # get the null Timeout prototype instance for comparison

# prevent environment changing tests
delete process.env.DIALOGUE_TIMEOUT
delete process.env.DIALOGUE_TIMEOUT_LINE

describe '#Dialogue', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom()
    @room.robot.on 'respond', (res) => @res = res # store every latest response
    @spy = _.mapObject Dialogue.prototype, (val, key) ->
      sinon.spy Dialogue.prototype, key # spy on all the class methods
    @room.user.say 'user1', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'with defaults', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      @room.robot.respond /.*/, (res) => @dialog.receive res # hear all messages

    afterEach ->
      clearTimeout @dialogue.countdown

    describe 'constructor', ->

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

      it 'has not started the timeout', ->
        @dialogue.countdown.should.not.exist

    describe '.choice', ->

      beforeEach ->
        @errorSpy = sinon.spy @room.robot.logger, 'error'

      context 'with a reply string', ->

        beforeEach ->
          @dialogue.choice /.*/, 'foo'

        it 'has object with regex and handler', ->
          @dialogue.choices[0].should.be.an 'object'
          @dialogue.choices[0].regex.should.be.instanceof RegExp
          @dialogue.choices[0].handler.should.be.a 'function'

        it 'does not clear (non-existent) timeout', ->
          @spy.clearTimeout.should.not.have.called

        it 'starts the timeout', ->
          @spy.startTimeout.should.have.calledOnce
          @dialogue.countdown.should.exist
          @dialogue.countdown.should.be.instanceof Timeout
          @dialogue.countdown._called.should.be.false

      context 'with a custom handler callback', ->

        beforeEach ->
          @dialogue.choice /.*/, () -> null

        it 'has object with regex and handler', ->
          @dialogue.choices[0].should.be.an 'object'
          @dialogue.choices[0].regex.should.be.instanceof RegExp
          @dialogue.choices[0].handler.should.be.a 'function'

        it 'starts the timeout', ->
          @spy.startTimeout.should.have.calledOnce
          @dialogue.countdown.should.exist
          @dialogue.countdown.should.be.instanceof Timeout
          @dialogue.countdown._called.should.be.false

      context 'with a reply and handler', ->

        beforeEach ->
          @dialogue.choice /.*/, 'foo', () -> null

        it 'has object with regex and handler', ->
          @dialogue.choices[0].should.be.an 'object'
          @dialogue.choices[0].regex.should.be.instanceof RegExp
          @dialogue.choices[0].handler.should.be.a 'function'

        it 'clears and restarts the timeout', ->
          @spy.clearTimeout.should.have.calledOnce
          @spy.startTimeout.should.have.calledOnce

      context 'with bad arguments', ->

        beforeEach ->
          @dialogue.choice /.*/, null
          @dialogue.choice /.*/, null, () -> null
          @dialogue.choice 'foo', 'bar', () -> null

        it 'log an error for each incorrect call', ->
          @errorSpy.should.have.calledThrice

        it 'does not have any choices loaded', ->
          @dialogue.choices.length.should.equal 0

        it 'does not clear or start timeout', ->
          @spy.clearTimeout.should.not.have.called
          @spy.startTimeout.should.not.have.called

      context 'with consecutive added choices', ->

        beforeEach ->
          @dialogue.choice /.*/, 'foo'
          @dialogue.choice /.*/, 'bar'

        it 'has kept both choices', ->
          @dialogue.choices.should.be.an 'array'
          @dialogue.choices.length.should.equal 2

        it 'clears and restarts the timeout', ->
          @spy.clearTimeout.should.have.calledOnce
          @spy.startTimeout.should.have.calledTwice

      context 'with a handler that adds another choice', ->

        beforeEach ->
          @yesSpy = sinon.spy()
          @dialogue.choice /confirm/, () => @dialogue.choice /yes/i, @yesSpy
          @room.user.say 'user1', 'confirm'

        afterEach ->
          @dialogue.end()

        it 'has new choice after matching original', ->
          @dialogue.choices.length.should.equal 1

        it 'calls second callback after matching sequence', ->
          @room.user.say 'user1', 'yes'
          .then => @yesSpy.should.have.calledOnce

    describe '.clearChoices', ->

      beforeEach ->
        @choiceSpy = sinon.spy()
        @dialogue.choice /.*/, @choicesSpy
        @dialogue.clearChoices()
        @room.user.say 'user1', 'test'

      it 'clears the array of choices', ->
        @dialogue.choices.should.be.an 'array'
        @dialogue.choices.length.should.equal 0

      it 'does not respond to prior added choices', ->
        @choicesSpy.should.not.have.called

    describe '.receive', ->

      beforeEach ->
        @dialogue.choice /1/, 'got 1'
        @handler1 = sinon.spy @dialogue.choices[0], 'handler'
        @handler2 = sinon.spy()
        @dialogue.choice /2/, @handler2
        @handler3 = sinon.spy()
        @dialogue.choice /3/, 'got 3', @handler3

      afterEach ->
        @handler1.restore()
        @handler2.restore()
        @handler3.restore()
        @dialogue.end()

      context 'matching choice with reply string', ->

        beforeEach ->
          @emitSpy = sinon.spy()
          @dialogue.on 'match', @emitSpy
          @room.user.say 'user1', '1'

        it 'emits match event with match, line and regex', ->
          @emitSpy.should.have.calledWith [ '1'.match('1'), '1', /1/, 'user1' ]

        it 'calls the created handler', ->
          @handler1.should.have.calledOnce

        it 'sends the response', ->
          @room.messages.pop().should.eql [ 'hubot', 'got 1' ]

      context 'matching choice with no reply and custom handler', ->

        beforeEach ->
          @emitSpy = sinon.spy()
          @dialogue.on 'match', @emitSpy
          @room.user.say 'user1', '2'

        it 'emits match event with match, line and regex', ->
          @emitSpy.should.have.calledWith [ '2'.match('2'), '2', /2/, 'user1' ]

        it 'calls the custom handler', ->
          @handler2.should.have.calledOnce

        it 'does not say anything new', ->
          @room.messages.pop().should.eql [ 'hubot', '@user1 pong' ]

      context 'matching choice with reply and custom handler', ->

        beforeEach ->
          @emitSpy = sinon.spy()
          @dialogue.on 'match', @emitSpy
          @room.user.say 'user1', '3'

        it 'emits match event with match, line and regex', ->
          @emitSpy.should.have.calledWith [ '3'.match('3'), '3', /3/, 'user3' ]

        it 'calls the custom handler', ->
          @handler3.should.have.calledOnce

        it 'sends the response', ->
          @room.messages.pop().should.eql [ 'hubot', 'got 3' ]

        it 'clears choices after match', ->
          @spy.clearChoices.should.have.calledOnce

      context 'received matching choices consecutively', ->

        beforeEach ->
          @room.user.say 'user1', '1'
          @room.user.say 'user1', '2'

        it 'clears choices after first only', ->
          @spy.clearChoices.should.have.calledOnce

        it 'does not reply to the second', ->
          @room.messages.pop().should.eql [ 'hubot', 'got 1' ]

      context 'when choice is matched and none added', ->

        beforeEach ->
          @room.user.say 'user1', '1'

        it 'ends dialogue', ->
          @spy.end.should.have.called

      context 'when choice is not matched', ->

        beforeEach ->
          @emitSpy = sinon.spy()
          @dialogue.on 'match', @emitSpy
          @room.user.say 'user1', '?'

        it 'does not emit match event', ->

        it 'emits mismatch event', ->

        it 'does not call end', ->

    describe '.send', ->

      beforeEach ->
        @dialogue.send 'test'

      it 'sends to the room from original res', ->
        @room.messages.pop().should.eql [ 'hubot', 'test' ]

    describe '.end', ->

      context 'when choices remain', ->

        beforeEach ->
          @dialogue.choice /.*/, () -> null
          @endSpy = sinon.spy()
          @dialogue.on 'end', @endSpy

        it 'emits successful complete status', ->
          @endSpy.should.have.calledWith true

        it 'sends ended to true', ->
          @dialogue.ended.should.be true

      context 'when no choices remain', ->

        @room.user.say 'user1', '1'

      context 'when already ended', ->

        it 'should not process consecutively', ->

    describe '.getChoices', ->

      beforeEach ->
        @dialogue.choice /.*/, 'foo'

      it 'returns the array of choices', ->
        @dialogue.getChoices().should.eql @dialogue.choices

    describe '.end', ->

      beforeEach ->
        @emitSpy = sinon.spy()
        @dialogue.on 'end', emitSpy
        @dialogue.end()

      it 'clears choices', ->
        @spy.clearChoices.should.have.called

      it 'clears timeout', ->
        @spy.clearTimeout.should.have.called

      it 'emits end event', ->
        @emitSpy.should.have.called

  context 'with env vars set', ->

    describe 'constructor', ->

      beforeEach ->
        process.env.DIALOGUE_TIMEOUT = 500
        process.env.DIALOGUE_TIMEOUT_LINE = 'Testing timeout env'
        @dialogue = new Dialogue @res

      afterEach ->
        @dialogue.end()
        delete process.env.DIALOGUE_TIMEOUT
        delete process.env.DIALOGUE_TIMEOUT_LINE

      it 'uses the environment timeout settings', ->
        @dialogue.config.timeout.should.equal 500
        @dialogue.config.timeoutLine.should.equal 'Testing timeout env'

  context 'with timout options', ->

    describe 'constructor', ->

      beforeEach ->
        @dialogue = new Dialogue @res,
          timeout: 555
          timeoutLine: 'Testing timeout options'

      afterEach ->
        @dialogue.end()

      it 'uses passed options', ->
        @dialogue.config.timeout.should.equal 555
        @dialogue.config.timeoutLine.should.equal 'Testing timeout options'

  context 'with 10ms timeout', ->

    beforeEach (done) ->
      @timeoutSpy = sinon.spy()
      @endSpy = sinon.spy()
      @dialogue = new Dialogue @res, timeout: 10
      @dialogue.on 'timeout', @timeoutSpy
      @dialogue.on 'end', @endSpy
      Q.delay(15).done -> done()

    afterEach ->
      @dialogue.end()

    describe '.startTimeout (expiring)', ->

      it 'emits timeout event', ->
        @timeoutSpy.should.have.calledOnce

      it 'calls onTimeout with response object', ->
        @spy.onTimeout.should.have.calledOnce
        @spy.onTimeout.should.have.calledWith @res

      it 'calls .end', ->
        @spy.end.should.have.calledOnce

    describe '.onTimeout', ->

      it 'sends timout message to room', ->
        @room.messages.should.eql [
          [ 'user1', 'hubot ping' ]
          [ 'hubot', '@user1 pong' ]
          [ 'hubot', @dialogue.config.timeoutLine ]
        ]

    describe '.end', ->

      it 'emits end event with false complete status', ->
        @endSpy.should.have.calledWith false

      it 'clear timeout should not ever be called', ->
        @spy.clearTimeout.should.not.have.called

# @TODO : .receive ends dialogue when no more choices
# @TODO : and ended dialogue cannot receive

# TODO: Ended dialogue will not receive or allow choices to be added - log error
