_ = require 'lodash'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

# test with env for defaults
process.env.DIALOGUE_TIMEOUT = 500

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Dialogue} = require '../../src/modules'

# get the null Timeout prototype instance for comparison
Timeout = setTimeout () ->
  null
, 0
.constructor

describe '#Dialogue', ->

  beforeEach ->
    pretend.startup()
    @tester = pretend.user 'tester'
    @clock = sinon.useFakeTimers()

    _.forIn Dialogue.prototype, (val, key) ->
      sinon.spy Dialogue.prototype, key if _.isFunction val

    # generate a response object for starting dialogues
    pretend.user('tester').send 'test'
    .then => @res = pretend.responses.incoming[0]

  afterEach ->
    pretend.shutdown()
    @clock.restore()

    _.forIn Dialogue.prototype, (val, key) ->
      Dialogue.prototype[key].restore() if _.isFunction val

  describe 'constructor', ->

    context 'with defaults, including an env var', ->

      beforeEach ->
        @dialogue = new Dialogue @res

      it 'has timeout value configured', ->
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
      pretend.robot.hear /.*/, (res) => @dialogue.receive res # hear all
      @end = sinon.spy()
      @dialogue.on 'end', @end

    context 'when no paths added', ->

      beforeEach ->
        @dialogue.end()

      it 'emits end event with success status (false)', ->
        @end.should.have.calledWith false

      it 'sets ended to true', ->
        @dialogue.ended.should.be.true

      it 'returns true', ->
        @dialogue.end.returnValues.pop().should.be.true

    context 'when path is not closed', ->

      beforeEach ->
        @dialogue.path = closed: false
        @dialogue.end()

      it 'clears the timeout', ->
        @dialogue.clearTimeout.should.have.calledOnce

      it 'emits end event with success status (false)', ->
        @end.should.have.calledWith false

      it 'sets ended to true', ->
        @dialogue.ended.should.be.true

      it 'returns true', ->
        @dialogue.end.returnValues.pop().should.be.true

    context 'when path is closed', ->

      beforeEach ->
        @dialogue.path = closed: true
        @dialogue.end()

      it 'clears the timeout', ->
        @dialogue.clearTimeout.should.have.calledOnce

      it 'emits end event with success status (true)', ->
        @end.should.have.calledWith true

      it 'sets ended to true', ->
        @dialogue.ended.should.be.true

      it 'returns true', ->
        @dialogue.end.returnValues.pop().should.be.true

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
        wait

      it 'sends to the room from original res', ->
        pretend.messages.pop().should.eql [ 'hubot', 'test' ]

      it 'emits send event', ->
        @send.should.have.calledOnce

    context 'with config.sendReplies set to true', ->

      beforeEach ->
        wait = pretend.observer.next()
        @send = sinon.spy()
        @dialogue.on 'send', @send
        @dialogue.config.sendReplies = true
        @dialogue.send 'test'
        wait

      it 'sends to the room from original res, responding to the @user', ->
        pretend.messages.pop().should.eql ['hubot', '@tester test' ]

  describe '.onTimeout', ->

    context 'default method', ->

      beforeEach ->
        wait = pretend.observer.next()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.startTimeout()
        @clock.tick 1001
        wait

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
        @timout = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.onTimeout = @timout
        @dialogue.startTimeout()
        @clock.tick 1001

      it 'calls the override method', ->
        @timout.should.have.calledOnce

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

    context 'with a prompt, branches and options', ->

      beforeEach ->
        @path = @dialogue.addPath 'Turn left or right?', [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ], key: 'which-way'

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'passes options to path', ->
        @path.config.key.should.eql 'which-way'

      it 'sends the prompt', ->
        @dialogue.send.should.have.calledWith 'Turn left or right?'

      it 'starts timout', ->
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

      it 'starts timout', ->
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

      it 'starts timout', ->
        @dialogue.startTimeout.should.have.calledOnce

    context 'without branches', ->

      beforeEach ->
        @path = @dialogue.addPath "Don't say nothing."

      it 'returns new Path instance', ->
        @path.should.be.instanceof @dialogue.Path

      it 'does not start timout', ->
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

      it 'starts timout', ->
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

      it 'starts timout', ->
        @dialogue.startTimeout.should.have.calledOnce

  describe '.receive', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      pretend.robot.hear /.*/, (res) => @result = @dialogue.receive res # hear all
      @dialogue.branch /1/, 'got 1'
      @errorr1 = sinon.spy @dialogue.branches[0], 'handler'
      @errorr2 = sinon.spy()
      @dialogue.branch /2/, @errorr2
      @errorr3 = sinon.spy()
      @dialogue.branch /3/, 'got 3', @errorr3

    afterEach ->
      @errorr1.restore()

    context 'match for branch with reply string', ->

      beforeEach ->
        @tester.send '1'

      it 'records the match (with user, line, match, regex)', ->
        @dialogue.record.should.have.calledWith 'match',
        @rec.message.user,
        '1',
        '1'.match('1'),
        /1/

      it 'calls the created handler', ->
        @errorr1.should.have.calledOnce

      it 'sends the response', ->
        pretend.messages.pop().should.eql [ 'hubot', 'got 1' ]

    context 'matching branch with no reply and custom handler', ->

      beforeEach ->
        @tester.send '2'

      it 'records the match (with user, line, match, regex)', ->
        @dialogue.record.should.have.calledWith 'match',
        @rec.message.user,
        '2',
        '2'.match('2'),
        /2/

      it 'calls the custom handler', ->
        @errorr2.should.have.calledOnce

      it 'hubot does not reply', ->
        pretend.messages.pop().should.eql [ 'tester', '2' ]

    context 'matching branch with reply and custom handler', ->

      beforeEach ->
        @tester.send '3'

      it 'records the match (with user, line, match, regex)', ->
        @dialogue.record.should.have.calledWith 'match',
        @rec.message.user,
        '3',
        '3'.match('3'),
        /3/

      it 'calls the custom handler', ->
        @errorr3.should.have.calledOnce

      it 'sends the response', ->
        pretend.messages.pop().should.eql [ 'hubot', 'got 3' ]

      it 'clears branches after match', ->
        @dialogue.clearBranches.should.have.calledOnce

    context 'received matching branches consecutively', ->

      beforeEach ->
        @tester.send '1'
        @tester.send '2'

      it 'clears branches after first only', ->
        @dialogue.clearBranches.should.have.calledOnce

      it 'does not reply to the second', ->
        pretend.messages.pop().should.eql [ 'hubot', 'got 1' ]

    context 'when branch is matched and none added', ->

      beforeEach ->
        @tester.send '1'

      it 'ends dialogue', ->
        @dialogue.end.should.have.called

    context 'when branch is not matched', ->

      beforeEach ->
        @tester.send '?'

      it 'records mismatch (with user, line)', ->
        @dialogue.record.should.have.calledWith 'mismatch',
        @rec.message.user,
        '?'

      it 'does not call end', ->
        @dialogue.end.should.not.have.called

    context 'when already ended', ->

      beforeEach ->
        @dialogue.end()
        @tester.send '1'

      it 'returns false', ->
        @result.should.be.false

      it 'does not call the handler', ->
        @errorr1.should.not.have.called

      it 'does not record anything', ->
        @dialogue.record.should.not.have.called
