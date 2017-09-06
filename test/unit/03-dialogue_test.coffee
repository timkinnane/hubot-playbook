sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
co = require 'co'
_ = require 'lodash'
pretend = require 'hubot-pretend'
Dialogue = require '../../lib/modules/dialogue'

# get the null Timeout prototype instance for comparison
Timeout = setTimeout () ->
  null
, 0
.constructor

# init some global test helpers
clock = null
testRes = null
matchRes = (value) ->
  responseKeys = [ 'robot', 'message', 'match', 'envelope', 'dialogue' ]
  difference = _.difference responseKeys, _.keys value
  difference.length == 0

describe 'Dialogue', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'
    testRes = pretend.response 'tester', 'test', 'testing'
    clock = sinon.useFakeTimers()
    Object.getOwnPropertyNames(Dialogue.prototype).map (key) ->
      sinon.spy Dialogue.prototype, key

  afterEach ->
    pretend.shutdown()
    clock.restore()
    Object.getOwnPropertyNames(Dialogue.prototype).map (key) ->
      Dialogue.prototype[key].restore()

  describe 'constructor', ->

    it 'has null path', ->
      dialogue = new Dialogue testRes
      should.equal dialogue.path, null

    it 'is not ended', ->
      dialogue = new Dialogue testRes
      dialogue.ended.should.be.false

    it 'uses timeout from env', ->
      process.env.DIALOGUE_TIMEOUT = 500
      dialogue = new Dialogue testRes
      dialogue.config.timeout.should.equal 500
      delete process.env.DIALOGUE_TIMEOUT

  describe '.end', ->

    context 'before messages received', ->

      it 'emits end with initial response', ->
        dialogue = new Dialogue testRes
        end = sinon.spy()
        dialogue.on 'end', end
        dialogue.end()
        end.should.have.calledWith testRes

      it 'sets ended to true', ->
        dialogue = new Dialogue testRes
        dialogue.end()
        dialogue.ended.should.be.true

      it 'returns true', ->
        dialogue = new Dialogue testRes
        dialogue.end()
        .should.be.true

    context 'after messages received', ->

      it 'emits end with latest response (containing dialogue)', ->
        dialogue = new Dialogue testRes
        end = sinon.spy()
        dialogue.on 'end', end
        dialogue.receive testRes
        dialogue.end()
        end.should.have.calledWith sinon.match matchRes

    context 'when timeout is running', ->

      it 'clears the timeout', ->
        dialogue = new Dialogue testRes
        dialogue.startTimeout()
        dialogue.end()
        dialogue.clearTimeout.should.have.calledOnce

    context 'when already ended', ->

      it 'returns false', ->
        dialogue = new Dialogue testRes
        dialogue.end()
        dialogue.end()
        .should.be.false

      it 'should only emit end event once', ->
        dialogue = new Dialogue testRes
        end = sinon.spy()
        dialogue.on 'end', end
        dialogue.end()
        dialogue.end()
        end.should.have.calledOnce

  describe '.send', ->

    context 'with config.sendReplies set to false', ->

      it 'sends to the room from original res', -> co ->
        dialogue = new Dialogue testRes
        yield dialogue.send 'test'
        pretend.messages.pop().should.eql [ 'testing', 'hubot', 'test' ]

      it 'emits send event with new response (containing dialogue)', -> co ->
        dialogue = new Dialogue testRes
        sendSpy = sinon.spy()
        dialogue.on 'send', sendSpy
        yield dialogue.send 'test'
        sendSpy.should.have.calledWith sinon.match matchRes

      it 'also emits with strings, methdod and original res', -> co ->
        dialogue = new Dialogue testRes
        sendSpy = sinon.spy()
        dialogue.on 'send', sendSpy
        yield dialogue.send 'test'
        sendSpy.lastCall.args[1].should.eql
          strings: [ 'test' ]
          method: 'send'
          received: testRes

    context 'with config.sendReplies set to true', ->

      it 'sends to room from original res, responding to the @user', -> co ->
        dialogue = new Dialogue testRes
        dialogue.config.sendReplies = true
        yield dialogue.send 'test'
        pretend.messages.pop().should.eql [ 'testing', 'hubot', '@tester test' ]

  describe '.onTimeout', ->

    context 'default method', ->

      it 'sends timeout message to room', ->
        wait = pretend.observer.next()
        dialogue = new Dialogue testRes, timeout: 1000
        dialogue.startTimeout()
        clock.tick 1001
        yield wait
        pretend.messages.pop().should.eql [
          'testing', 'hubot', dialogue.config.timeoutText
        ]

    context 'method override (as argument)', ->

      it 'calls the override method', ->
        dialogue = new Dialogue testRes
        dialogue.configure timeout: 1000
        timeout = sinon.spy()
        dialogue.onTimeout timeout
        dialogue.startTimeout()
        clock.tick 1001
        timeout.should.have.calledOnce

      it 'does not send the default timeout message', ->
        dialogue = new Dialogue testRes
        dialogue.configure timeout: 1000
        timeout = sinon.spy()
        dialogue.onTimeout timeout
        dialogue.startTimeout()
        clock.tick 1001
        dialogue.send.should.not.have.been.calledOnce

    context 'method override (by assignment)', ->

      it 'calls the override method', ->
        dialogue = new Dialogue testRes
        dialogue.configure timeout: 1000
        timeout = sinon.spy()
        dialogue.onTimeout = timeout
        dialogue.startTimeout()
        clock.tick 1001
        timeout.should.have.calledOnce

    context 'method override with invalid function', ->

      it 'throws exception', ->
        dialogue = new Dialogue testRes
        dialogue.configure timeout: 1000
        dialogue.onTimeout -> throw new Error "Test exception"
        override = sinon.spy dialogue, 'onTimeout'
        dialogue.startTimeout()
        try clock.tick 1001
        override.should.throw

  describe '.clearTimeout', ->

  describe '.startTimeout', ->

    it 'emits timeout event', ->
      dialogue = new Dialogue testRes
      dialogue.configure timeout: 1000
      timeoutMethod = sinon.spy()
      dialogue.onTimeout timeoutMethod
      timeoutEvent = sinon.spy()
      dialogue.on 'timeout', timeoutEvent
      dialogue.startTimeout()
      clock.tick 1001
      timeoutEvent.should.have.calledOnce

    it 'emits end event', ->
      dialogue = new Dialogue testRes
      dialogue.configure timeout: 1000
      end = sinon.spy()
      dialogue.on 'end', end
      timeoutMethod = sinon.spy()
      dialogue.onTimeout timeoutMethod
      dialogue.startTimeout()
      clock.tick 1001
      end.should.have.calledOnce

    it 'calls onTimeout method', ->
      dialogue = new Dialogue testRes
      dialogue.configure timeout: 1000
      timeoutMethod = sinon.spy()
      dialogue.onTimeout timeoutMethod
      dialogue.startTimeout()
      clock.tick 1001
      timeoutMethod.should.have.calledOnce

    it 'calls .end', ->
      dialogue = new Dialogue testRes
      dialogue.configure
        timeout: 1000
        timeoutText: null
      dialogue.startTimeout()
      clock.tick 1001
      dialogue.end.should.have.calledOnce

  describe '.addPath', ->

    context 'with a prompt, branches and key', ->

      it 'returns new Path instance', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], 'which-way'
        path.should.be.instanceof dialogue.Path

      it 'passes options to path', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], 'which-way'
        path.key.should.eql 'which-way'

      it 'sends the prompt', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], 'which-way'
        dialogue.send.should.have.calledWith 'Turn left or right?'

      it 'starts timeout', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], 'which-way'
        dialogue.startTimeout.should.have.calledOnce

    context 'with branches only', ->

      it 'returns new Path instance', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]
        path.should.be.instanceof dialogue.Path

      it 'sends nothing', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]
        dialogue.send.should.not.have.called

      it 'starts timeout', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]
        dialogue.startTimeout.should.have.calledOnce

    context 'without branches', ->

      it 'returns new Path instance', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath "Don't say nothing."
        path.should.be.instanceof dialogue.Path

      it 'does not start timeout', -> co ->
        dialogue = new Dialogue testRes
        path = yield dialogue.addPath "Don't say nothing."
        dialogue.startTimeout.should.not.have.called

  describe '.addBranch', ->

    context 'with existing path', ->

      it 'passes branch args on to path.addBranch', ->
        dialogue = new Dialogue testRes
        dialogue.path = addBranch: sinon.spy()
        dialogue.addBranch /foo/, 'foo'
        dialogue.path.addBranch.should.have.calledWith /foo/, 'foo'

      it 'starts timeout', ->
        dialogue = new Dialogue testRes
        dialogue.path = addBranch: sinon.spy()
        dialogue.addBranch /foo/, 'foo'
        dialogue.startTimeout.should.have.calledOnce

    context 'when no path exists', ->

      it 'creates a new path', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, 'foo'
        dialogue.path.should.be.instanceof dialogue.Path

      it 'passes branch args on to path.addBranch', ->
        dialogue = new Dialogue testRes
        sinon.spy dialogue.Path.prototype, 'addBranch'
        dialogue.addBranch /foo/, 'foo'
        dialogue.path.addBranch.should.have.calledWith /foo/, 'foo'

      it 'starts timeout', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, 'foo'
        dialogue.startTimeout.should.have.calledOnce

  describe '.receive', ->

    it 'stores the latest response object', ->
      dialogue = new Dialogue testRes
      dialogue.addBranch /.*/, ->
      dialogue.receive pretend.response 'tester', 'new test'
      dialogue.res.message.text.should.equal 'new test'

    it 'attaches itself to the response', ->
      dialogue = new Dialogue testRes
      dialogue.addBranch /.*/, ->
      newTestRes = pretend.response 'tester', 'new test'
      dialogue.receive newTestRes
      newTestRes.dialogue.should.eql dialogue

    context 'when already ended', ->

      it 'returns false', ->
        dialogue = new Dialogue testRes
        dialogue.end()
        dialogue.receive testRes
        .should.be.false

      it 'does not call the handler', ->
        dialogue = new Dialogue testRes
        callback = sinon.spy()
        dialogue.addBranch /.*/, callback
        dialogue.end()
        dialogue.receive testRes
        callback.should.not.have.called

    context 'on matching branch', ->

      it 'clears timeout', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, -> null
        dialogue.receive pretend.response 'tester', 'foo'
        dialogue.clearTimeout.should.have.calledOnce

      it 'ends dialogue', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, -> null
        dialogue.receive pretend.response 'tester', 'foo'
        dialogue.end.should.have.calledOnce

      it 'calls the branch handler', ->
        dialogue = new Dialogue testRes
        callback = sinon.spy()
        dialogue.addBranch /foo/, 'bar', callback
        dialogue.receive pretend.response 'tester', 'foo'
        callback.should.have.calledOnce

      it 'sends the branch message', ->
        dialogue = new Dialogue testRes
        callback = sinon.spy()
        dialogue.addBranch /foo/, 'bar', callback
        dialogue.receive pretend.response 'tester', 'foo'
        dialogue.send.should.have.calledWith 'bar'

    context 'on matching branches consecutively', ->

      it 'only processes first match', ->
        dialogue = new Dialogue testRes
        callback = sinon.spy()
        dialogue.addBranch /foo/, callback
        dialogue.addBranch /bar/, callback
        dialogue.receive pretend.response 'tester', 'foo'
        dialogue.receive pretend.response 'tester', 'bar'
        callback.should.have.calledOnce

    context 'on mismatch with catch', ->

      it 'sends the catch message', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, ->
        dialogue.path.config.catchMessage = 'huh?'
        dialogue.receive pretend.response 'tester', '?'
        dialogue.send.should.have.calledWith 'huh?'

      it 'does not clear timeout', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, ->
        dialogue.path.config.catchMessage = 'huh?'
        dialogue.receive pretend.response 'tester', '?'
        dialogue.clearTimeout.should.not.have.called

      it 'does not call end', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, ->
        dialogue.path.config.catchMessage = 'huh?'
        dialogue.receive pretend.response 'tester', '?'
        dialogue.end.should.not.have.called

    context 'on mismatch without catch', ->

      it 'does not clear timeout', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, ->
        dialogue.receive pretend.response 'tester', '?'
        dialogue.clearTimeout.should.not.have.called

      it 'does not call end', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /foo/, ->
        dialogue.receive pretend.response 'tester', '?'
        dialogue.end.should.not.have.called

    context 'on matching branch that adds a new branch', ->

      it 'added branches to current path', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /more/, ->
          dialogue.addBranch /1/, 'got 1'
          dialogue.addBranch /2/, 'got 2'
        dialogue.receive pretend.response 'tester', 'more'
        _.map dialogue.path.branches, (branch) -> branch.regex
          .should.eql [ /more/, /1/, /2/ ]

      it 'does not call end', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /more/, ->
          dialogue.addBranch /1/, 'got 1'
          dialogue.addBranch /2/, 'got 2'
        dialogue.receive pretend.response 'tester', 'more'
        dialogue.end.should.not.have.called

    context 'on matching branch that adds a new path', ->

      it 'added new branches to new path, overwrites prev path', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /new/, ->
          dialogue.addPath [ [ /1/, 'got 1' ], [ /2/, 'got 2' ] ]
        dialogue.receive pretend.response 'tester', 'new'
        _.map dialogue.path.branches, (branch) -> branch.regex
          .should.eql [ /1/, /2/ ]

      it 'does not call end', ->
        dialogue = new Dialogue testRes
        dialogue.addBranch /new/, ->
          dialogue.addPath [ [ /1/, 'got 1' ], [ /2/, 'got 2' ] ]
        dialogue.receive pretend.response 'tester', 'new'
        dialogue.end.should.not.have.called
