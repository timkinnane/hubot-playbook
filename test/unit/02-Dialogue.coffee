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

      it 'has empty paths object', ->
        @dialogue.paths.should.be.an 'object'
        _.size(@paths).should.equal 0

      it 'has a null value for current path', ->
        should.equal @dialogue.currentPath, null

      it 'has an empty branches array', ->
        @dialogue.branches.should.be.an 'array'
        @dialogue.branches.length.should.equal 0

      it 'has an ended status of false', ->
        @dialogue.ended.should.be.false

      it 'has config with defaults of correct type', ->
        @dialogue.config.should.be.an 'object'
        @dialogue.config.timeout.should.be.a 'number'
        @dialogue.config.timeoutLine.should.be.a 'string'

      it 'has not started the timeout', ->
        should.not.exist @dialogue.countdown

    describe '.keygen', ->

      context 'with a source string', ->

        beforeEach ->
          @result = @dialogue.keygen '%.test @# String!'

        it 'converts or removes unsafe characters', ->
          @result.should.equal 'test-String'

      context 'without source', ->

        beforeEach ->
          @result = @dialogue.keygen()

        it 'creates a string of 12 random characters', ->
          @result.length.should.equal 12

    describe '.path', ->

      context 'with a prompt, branches and key', ->

        beforeEach ->
          @dialogue.path 'Turn left or right?', [
            [ /left/, 'Ok, going left!' ]
            [ /right/, 'Ok, going right!' ]
          ], 'which-way'

        it 'does not create a key', ->
          @spy.keygen.should.not.have.called

      context 'with a prompt and branches (no key)', ->

        beforeEach ->
          @dialogue.path 'Pick door 1 or 2?', [
            [ /1/, 'You get cake!' ]
            [ /2/, 'You get cake!' ]
          ]

        it 'creates a key from the prompt', ->
          @spy.keygen.should.have.calledWith 'Pick door 1 or 2?'

      context 'with an empty prompt and branches', ->
        beforeEach ->
          @dialogue.path '', [
            [ /1/, 'You get cake!' ]
            [ /2/, 'You get cake!' ]
          ]

        it 'creates a random key', ->
          @spy.keygen.should.have.calledWith ''

    describe '.branch', ->

      beforeEach ->
        @errorSpy = sinon.spy @room.robot.logger, 'error'

      context 'with a reply string', ->

        beforeEach ->
          @dialogue.branch /.*/, 'foo'

        it 'has object with regex and handler', ->
          @dialogue.branches[0].should.be.an 'object'
          @dialogue.branches[0].regex.should.be.instanceof RegExp
          @dialogue.branches[0].handler.should.be.a 'function'

        it 'does not clear (non-existent) timeout', ->
          @spy.clearTimeout.should.not.have.called

        it 'starts the timeout', ->
          @spy.startTimeout.should.have.calledOnce
          @dialogue.countdown.should.be.instanceof Timeout

      context 'with a custom handler callback', ->

        beforeEach ->
          @dialogue.branch /.*/, () -> null

        it 'has object with regex and handler', ->
          @dialogue.branches[0].should.be.an 'object'
          @dialogue.branches[0].regex.should.be.instanceof RegExp
          @dialogue.branches[0].handler.should.be.a 'function'

      context 'with a reply and handler', ->

        beforeEach ->
          @dialogue.branch /.*/, 'foo', () -> null

        it 'has object with regex and handler', ->
          @dialogue.branches[0].should.be.an 'object'
          @dialogue.branches[0].regex.should.be.instanceof RegExp
          @dialogue.branches[0].handler.should.be.a 'function'

        it 'starts the timeout', ->
          @spy.startTimeout.should.have.calledOnce
          @dialogue.countdown.should.be.instanceof Timeout

      context 'with bad arguments', ->

        beforeEach ->
          unmute = mute() # remove error logs from test
          @dialogue.branch /.*/, null
          @dialogue.branch /.*/, null, () -> null
          @dialogue.branch 'foo', 'bar', () -> null
          unmute()

        it 'log an error for each incorrect call', ->
          @errorSpy.should.have.calledThrice

        it 'does not have any branches loaded', ->
          @dialogue.branches.length.should.equal 0

        it 'does not clear or start timeout', ->
          @spy.clearTimeout.should.not.have.called
          @spy.startTimeout.should.not.have.called
          should.not.exist @dialogue.countdown

      context 'with consecutive added branches', ->

        beforeEach ->
          @dialogue.branch /.*/, 'foo'
          @dialogue.branch /.*/, 'bar'

        it 'has kept both branches', ->
          @dialogue.branches.should.be.an 'array'
          @dialogue.branches.length.should.equal 2

        it 'clears and restarts the timeout', ->
          @spy.clearTimeout.should.have.calledOnce
          @spy.startTimeout.should.have.calledTwice

      context 'with a handler that adds another branch', ->

        beforeEach ->
          @yesSpy = sinon.spy()
          @dialogue.branch /confirm/, => @dialogue.branch /yes/, @yesSpy
          @room.user.say 'user1', 'confirm'

        it 'has new branch after matching original', ->
          @dialogue.branches.length.should.equal 1

        it 'calls second callback after matching sequence', ->
          @room.user.say 'user1', 'yes'
          .then => @yesSpy.should.have.calledOnce

      context 'when already ended', ->

        beforeEach ->
          unmute = mute()
          @dialogue.end()
          @size = @dialogue.branches.length
          @result = @dialogue.branch /.*/, 'testing'
          unmute()

        it 'should return false', ->
          @result.should.be.false

        it 'should not have added the branch', ->
          @dialogue.branches.length.should.equal @size

    describe '.clearBranches', ->

      beforeEach ->
        @branchespy = sinon.spy()
        @dialogue.branch /.*/, @branchespy
        @dialogue.clearBranches()
        @room.user.say 'user1', 'test'

      it 'clears the array of branches', ->
        @dialogue.branches.should.be.an 'array'
        @dialogue.branches.length.should.equal 0

      it 'does not respond to prior added branches', ->
        @branchespy.should.not.have.called

    describe '.receive', ->

      beforeEach ->
        @dialogue.branch /1/, 'got 1'
        @handler1 = sinon.spy @dialogue.branches[0], 'handler'
        @handler2 = sinon.spy()
        @dialogue.branch /2/, @handler2
        @handler3 = sinon.spy()
        @dialogue.branch /3/, 'got 3', @handler3

      afterEach ->
        @handler1.restore()

      context 'match for branch with reply string', ->

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

      context 'matching branch with no reply and custom handler', ->

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

      context 'matching branch with reply and custom handler', ->

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

        it 'clears branches after match', ->
          @spy.clearBranches.should.have.calledOnce

      context 'received matching branches consecutively', ->

        beforeEach ->
          @room.user.say 'user1', '1'
          @room.user.say 'user1', '2'

        it 'clears branches after first only', ->
          @spy.clearBranches.should.have.calledOnce

        it 'does not reply to the second', ->
          @room.messages.pop().should.eql [ 'hubot', 'got 1' ]

      context 'when branch is matched and none added', ->

        beforeEach ->
          @room.user.say 'user1', '1'

        it 'ends dialogue', ->
          @spy.end.should.have.called

      context 'when branch is not matched', ->

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
        @dialogue.branch /.*/, () -> null
        @end = sinon.spy()
        @dialogue.on 'end', @end

      context 'when branches remain', ->

        beforeEach ->
          @dialogue.end()

        it 'sets ended to true', ->
          @dialogue.ended.should.be.true

        it 'emits end event with success status (false)', ->
          @end.should.have.calledWith false

        it 'clears the timeout', ->
          @spy.clearTimeout.should.have.calledOnce

      context 'when triggered by last branch match', ->

        beforeEach ->
          @room.user.say 'user1', '1'

        it 'emits end event with unsuccessful status', ->
          @end.should.have.calledWith true

        it 'sets ended to true', ->
          @dialogue.ended.should.be.true

        it 'clears the timeout only once (from match)', ->
          @spy.clearTimeout.should.have.calledOnce

      context 'when already ended (by last branch match)', ->

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
