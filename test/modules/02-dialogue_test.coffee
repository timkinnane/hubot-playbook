sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

_ = require 'lodash'
pretend = require 'hubot-pretend'
Dialogue = require '../../lib/modules/dialogue'

# get the null Timeout prototype instance for comparison
Timeout = setTimeout () ->
  null
, 0
.constructor

describe 'Dialogue', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'
    @tester = pretend.user 'tester'
    @clock = sinon.useFakeTimers()

    Object.getOwnPropertyNames(Dialogue.prototype).map (key) ->
      sinon.spy Dialogue.prototype, key

    # generate a response object for starting dialogues
    yield pretend.user('tester').send 'test'
    @res = pretend.responses.incoming[0]

  afterEach ->
    pretend.shutdown()
    @clock.restore()

    Object.getOwnPropertyNames(Dialogue.prototype).map (key) ->
      Dialogue.prototype[key].restore()

  describe 'constructor', ->

    beforeEach ->
      @dialogue = new Dialogue @res

    it 'has null path', ->
      should.equal @dialogue.path, null

    it 'is not ended', ->
      @dialogue.ended.should.be.false

    context 'with defaults, including an env var', ->

      beforeEach ->
        process.env.DIALOGUE_TIMEOUT = 500
        @dialogue = new Dialogue @res

      afterEach ->
        delete process.env.DIALOGUE_TIMEOUT

      it 'has timeout value configured from env', ->
        @dialogue.config.timeout.should.equal 500

      it 'has timeout text configured', ->
        @dialogue.config.timeoutText.should.be.a 'string'

    context 'with timeout options', ->

      beforeEach ->
        @dialogue = new Dialogue @res,
          timeout: 555
          timeoutText: 'Testing timeout options'

      it 'uses passed timeout value', ->
        @dialogue.config.timeout.should.equal 555

      it 'uses passed timeout text', ->
        @dialogue.config.timeoutText.should.equal 'Testing timeout options'

  describe '.end', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      pretend.robot.hear /.*/, (res) => @dialogue.receive res # receive all
      @end = sinon.spy()
      @dialogue.on 'end', @end

    context 'before messages received', ->

      beforeEach ->
        @dialogue.end()

      it 'emits end with self and initial response', ->
        @end.should.have.calledWith @dialogue, @res

      it 'sets ended to true', ->
        @dialogue.ended.should.be.true

      it 'returns true', ->
        @dialogue.end.returnValues.pop().should.be.true

    context 'after messages received', ->

      beforeEach ->
        @tester.send 'foo'
        @dialogue.end()

      it 'emits end with self and latest response', ->
        @end.should.have.calledWith @dialogue, pretend.responses.incoming.pop()

    context 'when timeout is running', ->

      beforeEach ->
        @dialogue.startTimeout()
        @dialogue.end()

      it 'clears the timeout', ->
        @dialogue.clearTimeout.should.have.calledOnce

    context 'when already ended', ->

      beforeEach ->
        @dialogue.end()
        @dialogue.end()

      it 'returns false', ->
        @dialogue.end.returnValues.pop().should.be.false

      it 'should only emit end event once', ->
        @end.should.have.calledOnce

  describe '.send', ->

    beforeEach ->
      @dialogue = new Dialogue @res

    context 'with config.sendReplies set to false', ->

      beforeEach ->
        wait = pretend.observer.next()
        @send = sinon.spy()
        @dialogue.on 'send', @send
        @dialogue.send 'test'
        yield wait

      it 'sends to the room from original res', ->
        pretend.messages.pop().should.eql [ 'hubot', 'test' ]

      it 'emits send event with original response and sent strings', ->
        @send.should.have.calledWith @dialogue, @res, 'test'

    context 'with config.sendReplies set to true', ->

      beforeEach ->
        wait = pretend.observer.next()
        @send = sinon.spy()
        @dialogue.on 'send', @send
        @dialogue.config.sendReplies = true
        @dialogue.send 'test'
        yield wait

      it 'sends to the room from original res, responding to the @user', ->
        pretend.messages.pop().should.eql ['hubot', '@tester test' ]

  describe '.onTimeout', ->

    context 'default method', ->

      beforeEach ->
        wait = pretend.observer.next()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.startTimeout()
        @clock.tick 1001
        yield wait

      it 'sends timeout message to room', ->
        pretend.messages.pop().should.eql [
          'hubot', @dialogue.config.timeoutText
        ]

    context 'method override (as argument)', ->

      beforeEach ->
        @timeout = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.onTimeout @timeout
        @dialogue.startTimeout()
        @clock.tick 1001

      it 'calls the override method', ->
        @timeout.should.have.calledOnce

      it 'does not send the default timeout message', ->
        pretend.messages.pop().should.not.eql [
          'hubot', @dialogue.config.timeoutText
        ]

    context 'method override (by assignment)', ->

      beforeEach ->
        @timeout = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.onTimeout = @timeout
        @dialogue.startTimeout()
        @clock.tick 1001

      it 'calls the override method', ->
        @timeout.should.have.calledOnce

    context 'method override with invalid function', ->

      beforeEach ->
        @dialogue = new Dialogue @res, timeout: 1000
        @oldTimeout = @dialogue.onTimeout
        @dialogue.onTimeout -> throw new Error "Test exception"
        @override = sinon.spy @dialogue, 'onTimeout'
        @dialogue.startTimeout()
        try @clock.tick 1001

      afterEach ->
        @dialogue.onTimeout = @oldTimeout

      it 'throws exception', ->
        @override.should.have.threw

  describe '.clearTimeout', ->

  describe '.startTimeout', ->

    context 'with 1 second timeout', ->

      beforeEach ->
        @timeout = sinon.spy()
        @end = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.on 'timeout', @timeout
        @dialogue.on 'end', @end
        @dialogue.startTimeout()
        @clock.tick 1000

      it 'emits timeout event', ->
        @timeout.should.have.calledOnce

      it 'emits end event', ->
        @end.should.have.calledOnce

      it 'calls .onTimeout', ->
        @dialogue.onTimeout.should.have.calledOnce

      it 'calls .end', ->
        @dialogue.end.should.have.calledOnce

  describe '.addPath', ->

    beforeEach ->
      @dialogue = new Dialogue @res

    context 'with a prompt, branches and key', ->

      beforeEach ->
        @path = @dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], 'which-way'

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'passes options to path', ->
        @path.key.should.eql 'which-way'

      it 'sends the prompt', ->
        @dialogue.send.should.have.calledWith 'Turn left or right?'

      it 'starts timeout', ->
        @dialogue.startTimeout.should.have.calledOnce

    context 'with a prompt and branches (no options)', ->

      beforeEach ->
        @path = @dialogue.addPath 'Pick door 1 or 2?', [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'sends the prompt', ->
        @dialogue.send.should.have.calledWith 'Pick door 1 or 2?'

      it 'starts timeout', ->
        @dialogue.startTimeout.should.have.calledOnce

    context 'with branches only', ->

      beforeEach ->
        @path = @dialogue.addPath [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'sends nothing', ->
        @dialogue.send.should.not.have.called

      it 'starts timeout', ->
        @dialogue.startTimeout.should.have.calledOnce

    context 'without branches', ->

      beforeEach ->
        @path = @dialogue.addPath "Don't say nothing."

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'does not start timeout', ->
        @dialogue.startTimeout.should.not.have.called

  describe '.addBranch', ->

    beforeEach ->
      @dialogue = new Dialogue @res

    context 'with existing path', ->

      beforeEach ->
        @dialogue.path = addBranch: sinon.spy()
        @dialogue.addBranch /foo/, 'foo'

      it 'passes branch args on to path.addBranch', ->
        @dialogue.path.addBranch.should.have.calledWith /foo/, 'foo'

      it 'starts timeout', ->
        @dialogue.startTimeout.should.have.calledOnce

    context 'when no path exists', ->

      beforeEach ->
        sinon.spy @dialogue.Path.prototype, 'addBranch'
        @dialogue.addBranch /foo/, 'foo'

      afterEach ->
        @dialogue.Path.prototype.addBranch.restore()

      it 'creates a new path', ->
        @dialogue.path.should.be.instanceof @dialogue.Path

      it 'passes branch args on to path.addBranch', ->
        @dialogue.path.addBranch.should.have.calledWith /foo/, 'foo'

      it 'starts timeout', ->
        @dialogue.startTimeout.should.have.calledOnce

  describe '.receive', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      pretend.robot.hear /.*/, (res) => @dialogue.receive res # receive all
      @handler1 = sinon.spy()
      @handler2 = sinon.spy()
      @dialogue.addPath [
        [ /foo/, 'bar' ]
        [ /1/, 'got 1', @handler1 ]
        [ /2/, @handler2 ]
        [ /3/, 'got 3' ]
      ], key: 'receive-test'
      @handler3 = sinon.spy @dialogue.path.branches[3], 'handler'
      @match = sinon.spy()
      @mismatch = sinon.spy()
      @catch = sinon.spy()
      @dialogue.on 'match', @match
      @dialogue.on 'mismatch', @mismatch
      @dialogue.on 'catch', @catch
      @matchArgs = [
        sinon.match.instanceOf Dialogue
        sinon.match.instanceOf pretend.robot.Response
      ]

    context 'when already ended', ->

      beforeEach ->
        @dialogue.end()
        yield @tester.send '1'

      it 'returns false', ->
        @dialogue.receive.returnValues[0].should.be.false

      it 'does not call the handler', ->
        @handler1.should.not.have.called

    context 'on matching branch', ->

      beforeEach ->
        yield @tester.send 'foo'

      it 'clears timeout', ->
        @dialogue.clearTimeout.should.have.calledOnce

      it 'emits match with self and res', ->
        @match.should.have.calledWith @matchArgs...

      it 'ends dialogue', ->
        @dialogue.end.should.have.calledOnce

    context 'on matching branch with message and handler', ->

      beforeEach ->
        yield @tester.send '1'

      it 'calls the created handler', ->
        @handler1.should.have.calledOnce

      it 'sends the message', ->
        @dialogue.send.should.have.calledWith 'got 1'

    context 'on matching branch with just a handler', ->

      beforeEach ->
        yield @tester.send '2'

      it 'calls the custom handler', ->
        @handler2.should.have.calledOnce

      it 'does not send any messages', ->
        @dialogue.send.should.not.have.called

    context 'on matching branch with just a message', ->

      beforeEach ->
        yield @tester.send '3'

      it 'calls the default handler', ->
        @handler3.should.have.calledOnce

      it 'sends the response', ->
        @dialogue.send.should.have.calledWith 'got 3'

    context 'on matching branches consecutively', ->

      beforeEach ->
        yield @tester.send '1'
        yield @tester.send '2'

      it 'only processes first match', ->
        @match.should.have.calledOnce

      it 'does not reply to the second', ->
        @dialogue.send.should.not.have.calledWith 'got 2'

    context 'on mismatch with catch', ->

      beforeEach ->
        @dialogue.path.config.catchMessage = 'huh?'
        yield @tester.send '?'

      it 'emits catch with self and res', ->
        @catch.should.have.calledWith @matchArgs...

      it 'sends the catch message', ->
        @dialogue.send.should.have.calledWith 'huh?'

      it 'does not clear timeout', ->
        @dialogue.clearTimeout.should.not.have.called

      it 'does not call end', ->
        @dialogue.end.should.not.have.called

    context 'on mismatch without catch', ->

      beforeEach ->
        yield @tester.send '?'

      it 'emits mismatch with self and res', ->
        @mismatch.should.have.calledWith @matchArgs...

      it 'does not clear timeout', ->
        @dialogue.clearTimeout.should.not.have.called

      it 'does not call end', ->
        @dialogue.end.should.not.have.called

    context 'on matching branch that adds a new branch', ->

      beforeEach ->
        @dialogue.addBranch /more/, =>
          @dialogue.addBranch /4/, 'got 4'
          @dialogue.addBranch /5/, 'got 5'
        yield @tester.send 'more'

      it 'added branches to current path', ->
        _.map @dialogue.path.branches, (branch) -> branch.regex
          .should.eql [ /foo/, /1/, /2/, /3/, /more/, /4/, /5/ ]

      it 'does not call end', ->
        @dialogue.end.should.not.have.called

    context 'on matching branch that adds a new path', ->

      beforeEach ->
        @dialogue.addBranch /new/, =>
          @dialogue.addPath [
            [ /1/, 'got 1' ]
            [ /2/, 'got 2' ]
          ]
        yield @tester.send 'new'

      it 'added new branches to new path, overwrites prev path', ->
        _.map @dialogue.path.branches, (branch) -> branch.regex
          .should.eql [ /1/, /2/ ]

      it 'does not call end', ->
        @dialogue.end.should.not.have.called
