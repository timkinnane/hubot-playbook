Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper '../scripts/ping.coffee'
Observer = require '../utils/observer'

Dialogue = require '../../src/modules/Dialogue'
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
    @observer = new Observer @room.messages
    @room.robot.on 'respond', (res) => @res = res # store every response sent
    @room.robot.on 'receive', (res) => @rec = res # store every message received
    @spy = _.mapObject Dialogue.prototype, (val, key) ->
      sinon.spy Dialogue.prototype, key # spy on all the class methods
    @room.user.say 'user1', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'with defaults', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      @room.robot.hear /.*/, (res) => @result = @dialogue.receive res # hear all

    afterEach ->
      @dialogue.end()

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
        should.not.exist @dialogue.countdown

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
          @dialogue.countdown.should.be.instanceof Timeout

      context 'with a custom handler callback', ->

        beforeEach ->
          @dialogue.choice /.*/, () -> null

        it 'has object with regex and handler', ->
          @dialogue.choices[0].should.be.an 'object'
          @dialogue.choices[0].regex.should.be.instanceof RegExp
          @dialogue.choices[0].handler.should.be.a 'function'

      context 'with a reply and handler', ->

        beforeEach ->
          @dialogue.choice /.*/, 'foo', () -> null

        it 'has object with regex and handler', ->
          @dialogue.choices[0].should.be.an 'object'
          @dialogue.choices[0].regex.should.be.instanceof RegExp
          @dialogue.choices[0].handler.should.be.a 'function'

        it 'starts the timeout', ->
          @spy.startTimeout.should.have.calledOnce
          @dialogue.countdown.should.be.instanceof Timeout

      context 'with bad arguments', ->

        beforeEach ->
          unmute = mute() # remove error logs from test
          @dialogue.choice /.*/, null
          @dialogue.choice /.*/, null, () -> null
          @dialogue.choice 'foo', 'bar', () -> null
          unmute()

        it 'log an error for each incorrect call', ->
          @errorSpy.should.have.calledThrice

        it 'does not have any choices loaded', ->
          @dialogue.choices.length.should.equal 0

        it 'does not clear or start timeout', ->
          @spy.clearTimeout.should.not.have.called
          @spy.startTimeout.should.not.have.called
          should.not.exist @dialogue.countdown

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
          @dialogue.choice /confirm/, => @dialogue.choice /yes/, @yesSpy
          @room.user.say 'user1', 'confirm'

        it 'has new choice after matching original', ->
          @dialogue.choices.length.should.equal 1

        it 'calls second callback after matching sequence', ->
          @room.user.say 'user1', 'yes'
          .then => @yesSpy.should.have.calledOnce

      context 'when already ended', ->

        beforeEach ->
          unmute = mute()
          @dialogue.end()
          @size = @dialogue.choices.length
          @result = @dialogue.choice /.*/, 'testing'
          unmute()

        it 'should return false', ->
          @result.should.be.false

        it 'should not have added the choice', ->
          @dialogue.choices.length.should.equal @size

    describe '.clearChoices', ->

      beforeEach ->
        @choiceSpy = sinon.spy()
        @dialogue.choice /.*/, @choiceSpy
        @dialogue.clearChoices()
        @room.user.say 'user1', 'test'

      it 'clears the array of choices', ->
        @dialogue.choices.should.be.an 'array'
        @dialogue.choices.length.should.equal 0

      it 'does not respond to prior added choices', ->
        @choiceSpy.should.not.have.called

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

      context 'match for choice with reply string', ->

        beforeEach ->
          @match = sinon.spy()
          @dialogue.on 'match', @match
          @room.user.say 'user1', '1'

        it 'emits match event', ->
          @match.should.have.calledOnce

        it 'event has user, line, match and regex', ->
          @match.should.have.calledWith @rec.message.user,'1','1'.match('1'),/1/

        it 'calls the created handler', ->
          @handler1.should.have.calledOnce

        it 'sends the response', ->
          @room.messages.pop().should.eql [ 'hubot', 'got 1' ]

      context 'matching choice with no reply and custom handler', ->

        beforeEach ->
          @match = sinon.spy()
          @dialogue.on 'match', @match
          @room.user.say 'user1', '2'

        it 'event has user, line, match and regex', ->
          @match.should.have.calledWith @rec.message.user,'2','2'.match('2'),/2/

        it 'calls the custom handler', ->
          @handler2.should.have.calledOnce

        it 'hubot does not reply', ->
          @room.messages.pop().should.eql [ 'user1', '2' ]

      context 'matching choice with reply and custom handler', ->

        beforeEach ->
          @match = sinon.spy()
          @dialogue.on 'match', @match
          @room.user.say 'user1', '3'

        it 'event has user, line, match and regex', ->
          @match.should.have.calledWith @rec.message.user,'3','3'.match('3'),/3/

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
          @match = sinon.spy()
          @mismatch = sinon.spy()
          @dialogue.on 'match', @match
          @dialogue.on 'mismatch', @mismatch
          @room.user.say 'user1', '?'

        it 'does not emit match event', ->
          @match.should.not.have.called

        it 'emits mismatch event', ->
          @mismatch.should.have.called

        it 'mismatch event has user and line', ->
          @mismatch.should.have.calledWith @rec.message.user,'?'

        it 'does not call end', ->
          @spy.end.should.not.have.called

      context 'when already ended', ->

        beforeEach ->
          @match = sinon.spy()
          @dialogue.on 'match', @match
          @dialogue.end()
          @room.user.say 'user1', '1'

        it 'returns false', ->
          @result.should.be.false

        it 'does not call the handler', ->
          @handler1.should.not.have.called

        it 'does not emit match event', ->
          @match.should.not.have.called

    describe '.send', ->

      beforeEach (done) ->
        @observer.next().then -> done() # watch for response before proceeding
        @dialogue.send 'test'

      it 'sends to the room from original res', ->
        @room.messages.pop().should.eql [ 'hubot', 'test' ]

    describe '.end', ->

      beforeEach ->
        @dialogue.choice /.*/, () -> null
        @end = sinon.spy()
        @dialogue.on 'end', @end

      context 'when choices remain', ->

        beforeEach ->
          @dialogue.end()

        it 'sets ended to true', ->
          @dialogue.ended.should.be.true

        it 'emits end event with success status (false)', ->
          @end.should.have.calledWith false

        it 'clears the timeout', ->
          @spy.clearTimeout.should.have.calledOnce

      context 'when triggered by last choice match', ->

        beforeEach ->
          @room.user.say 'user1', '1'

        it 'emits end event with unsuccessful status', ->
          @end.should.have.calledWith true

        it 'sets ended to true', ->
          @dialogue.ended.should.be.true

        it 'clears the timeout only once (from match)', ->
          @spy.clearTimeout.should.have.calledOnce

      context 'when already ended (by last choice match)', ->

        beforeEach ->
          @room.user.say 'user1', '1'
          .then => @result = @dialogue.end()

        it 'should not process consecutively', ->
          @result.should.be.false

        it 'should only emit end event once', ->
          @end.should.have.calledOnce

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

    describe '.startTimeout (on countdown expiring)', ->

      beforeEach ->
        @timeout = sinon.spy()
        @end = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 10
        @dialogue.on 'timeout', @timeout
        @dialogue.on 'end', @end
        @dialogue.startTimeout()
        Q.delay 15

      it 'emits timeout event', ->
        @timeout.should.have.calledOnce

      it 'emits end event', ->
        @end.should.have.calledOnce

      it 'calls onTimeout', ->
        @spy.onTimeout.should.have.calledOnce

      it 'calls .end', ->
        @spy.end.should.have.calledOnce

    describe '.onTimeout', ->

      context 'default method', ->

        beforeEach ->
          @dialogue = new Dialogue @res, timeout: 10
          @dialogue.startTimeout()
          Q.delay 15

        it 'sends timout message to room', ->
          @room.messages.pop().should.eql [
            'hubot', @dialogue.config.timeoutLine
          ]

      context 'method override (as argument)', ->

        beforeEach ->
          @override = sinon.spy()
          @dialogue = new Dialogue @res, timeout: 10
          @dialogue.onTimeout.restore() # remove original spy
          @dialogue.onTimeout @override
          @dialogue.startTimeout()
          Q.delay 15

        it 'calls the override method', ->
          @override.should.have.calledOnce

        it 'does not send the default timeout message', ->
          @room.messages.pop().should.not.eql [
            'hubot', @dialogue.config.timeoutLine
          ]

      context 'method override (by assignment)', ->

        beforeEach ->
          @override = sinon.spy()
          @dialogue = new Dialogue @res, timeout: 10
          @dialogue.onTimeout = @override
          @dialogue.startTimeout()
          Q.delay 15

        it 'calls the override method', ->
          @override.should.have.calledOnce

      context 'method override with invalid function', ->

        beforeEach ->
          unmute = mute()
          @dialogue = new Dialogue @res, timeout: 10
          @dialogue.onTimeout -> throw new Error "Test exception"
          @override = sinon.spy @dialogue, 'onTimeout'
          @dialogue.startTimeout()
          Q.delay 15
          .then -> unmute()

        it 'throws exception (caught by timeout)', ->
          @override.should.have.threw

        it 'continues to execute and end', ->
          @spy.end.should.have.called
