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
    pretend.user('tester').in('testing').send 'test'
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

      afterEach ->
        @dialogue.end()

      it 'has timeout value configured', ->
        @dialogue.config.timeout.should.equal 500

      it 'has timeout text configured', ->
        @dialogue.config.timeoutText.should.be.a 'string'

    context 'with timeout options', ->

      beforeEach ->
        @dialogue = new Dialogue @res,
          timeout: 555
          timeoutText: 'Testing timeout options'

      afterEach ->
        @dialogue.end()

      it 'uses passed timeout value', ->
        @dialogue.config.timeout.should.equal 555

      it 'uses passed timeout text', ->
        @dialogue.config.timeoutText.should.equal 'Testing timeout options'

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

  describe '.path', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      pretend.robot.hear /.*/, (res) => @result = @dialogue.receive res

    context 'with a prompt, branches and key', ->

      beforeEach ->
        @pathId = @dialogue.path
          prompt: 'Turn left or right?'
          branches: [
            [ /left/, 'Ok, going left!' ]
            [ /right/, 'Ok, going right!' ]
          ]
          key: 'which-way'

      it 'clears branches', ->
        @dialogue.clearBranches.should.have.calledOnce

      it 'creates branches with branch property array elements', ->
        @dialogue.branch.should.have.calledWith [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]

      it 'returns the id using namespace and key', ->
        @pathId.should.match /^path_which-way/

      it 'returned id corresponds to a path object', ->
        @dialogue.paths[@pathId].should.be.an.object
        @dialogue.paths[@pathId].should.have.property 'prompt'
        @dialogue.paths[@pathId].should.have.property 'status'
        @dialogue.paths[@pathId].should.have.property 'transcript'

      it 'path object has prompt', ->
        @dialogue.paths[@pathId].prompt.should.equal 'Turn left or right?'

      it 'path object has status of branch adds (both success)', ->
        @dialogue.paths[@pathId].status.should.eql [ true, true ]

      it 'path object has transcript containing sent prompt', ->
        @dialogue.paths[@pathId].transcript.should.eql [
          [ 'send', 'bot', 'Turn left or right?']
        ]

      it 'sends the prompt to room', ->
        pretend.messages.pop().should.eql [ 'hubot', 'Turn left or right?' ]

    context 'with a prompt and branches (no key)', ->

      beforeEach (done) ->
        wait = pretend.observer.next()
        @result = @dialogue.path
          prompt: 'Pick door 1 or 2?'
          branches: [
            [ /1/, 'You get cake!' ]
            [ /2/, 'You get cake!' ]
          ]
        wait

      it 'creates id from path scope and prompt', ->
        @dialogue.keygen.should.have.calledWith 'path_Pick door 1 or 2?'

      it 'returned id corresponds to a path object', ->
        @dialogue.paths[@result].should.be.an.object
        @dialogue.paths[@result].should.have.property 'prompt'
        @dialogue.paths[@result].should.have.property 'status'
        @dialogue.paths[@result].should.have.property 'transcript'

      it 'sends the prompt', ->
        @dialogue.send.should.have.calledWith 'Pick door 1 or 2?'

    context 'without a prompt or key (branches only)', ->

      beforeEach ->
        @result = @dialogue.path
          branches: [
            [ /1/, 'You get cake!' ]
            [ /2/, 'You get cake!' ]
          ]

      it 'creates id from path scope alone', ->
        @dialogue.keygen.should.have.calledWith 'path_'

      it 'creates branches with branch property array elements', ->
        @dialogue.branch.should.have.calledWith /1/, 'You get cake!'
        @dialogue.branch.should.have.calledWith /2/, 'You get cake!'

      it 'returned id corresponds to a path object', ->
        @dialogue.paths[@result].should.be.an.object
        @dialogue.paths[@result].should.have.property 'prompt'
        @dialogue.paths[@result].should.have.property 'status'
        @dialogue.paths[@result].should.have.property 'transcript'

      it 'sends nothing', ->
        @dialogue.send.should.not.have.called

      it 'path object has empty transcript array', ->
        @dialogue.paths[@result].transcript.should.eql []

    context 'with only branches, as array argument', ->

      beforeEach ->
        @result = @dialogue.path [
          [ /1/, 'You get cake!' ]
          [ /2/, 'You get cake!' ]
        ]

      it 'creates id from path scope alone', ->
        @dialogue.keygen.should.have.calledWith 'path_'

      it 'creates branches with array elements', ->
        @dialogue.branch.should.have.calledWith /1/, 'You get cake!'
        @dialogue.branch.should.have.calledWith /2/, 'You get cake!'

      it 'returned id corresponds to a path object', ->
        @dialogue.paths[@result].should.be.an.object
        @dialogue.paths[@result].should.have.property 'prompt'
        @dialogue.paths[@result].should.have.property 'status'
        @dialogue.paths[@result].should.have.property 'transcript'

      it 'sends nothing', ->
        @dialogue.send.should.not.have.called

  describe '.branch', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      @robot.hear /.*/, (res) => @result = @dialogue.receive res # hear all

    context 'with a reply string', ->

      beforeEach ->
        @result = @dialogue.branch /.*/, 'foo'

      it 'has object with regex and handler', ->
        @dialogue.branches[0].should.be.an 'object'
        @dialogue.branches[0].regex.should.be.instanceof RegExp
        @dialogue.branches[0].handler.should.be.a 'function'

      it 'does not clear (non-existent) timeout', ->
        @dialogue.clearTimeout.should.not.have.called

      it 'starts the timeout', ->
        @dialogue.startTimeout.should.have.calledOnce
        @dialogue.countdown.should.be.instanceof Timeout

      it 'returns true', ->
        @result.should.be.true

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
        @dialogue.startTimeout.should.have.calledOnce
        @dialogue.countdown.should.be.instanceof Timeout

    context 'with bad arguments', ->

      beforeEach ->
        unmute = mute() # remove error logs from test
        @r1 = @dialogue.branch /.*/, null
        @r2 = @dialogue.branch /.*/, null, () -> null
        @r3 = @dialogue.branch 'foo', 'bar', () -> null
        unmute()

      it 'does not have any branches loaded', ->
        @dialogue.branches.length.should.equal 0

      it 'does not clear or start timeout', ->
        @dialogue.clearTimeout.should.not.have.called
        @dialogue.startTimeout.should.not.have.called
        should.not.exist @dialogue.countdown

      it 'returns false', ->
        @r1.should.be.false
        @r2.should.be.false
        @r3.should.be.false

    context 'with consecutive added branches', ->

      beforeEach ->
        @dialogue.branch /.*/, 'foo'
        @dialogue.branch /.*/, 'bar'

      it 'has kept both branches', ->
        @dialogue.branches.should.be.an 'array'
        @dialogue.branches.length.should.equal 2

      it 'clears and restarts the timeout', ->
        @dialogue.clearTimeout.should.have.calledOnce
        @dialogue.startTimeout.should.have.calledTwice

    context 'with a handler that adds another branch', ->

      beforeEach ->
        @callback = sinon.spy()
        @dialogue.branch /confirm/, =>
          @dialogue.branch /yes/, @callback
        @tester.send 'confirm'

      it 'has new branch after matching original', ->
        @dialogue.branches.length.should.equal 1

      it 'calls second callback after matching sequence', ->
        @tester.send 'yes'
        .then => @callback.should.have.calledOnce

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
      @dialogue = new Dialogue @res
      @robot.hear /.*/, (res) => @result = @dialogue.receive res # hear all
      @callback = sinon.spy()
      @dialogue.branch /.*/, @callback
      @dialogue.clearBranches()
      @tester.send 'test'

    it 'clears the array of branches', ->
      @dialogue.branches.length.should.equal 0

    it 'does not respond to prior added branches', ->
      @callback.should.not.have.called

  describe '.receive', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      @robot.hear /.*/, (res) => @result = @dialogue.receive res # hear all
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

  describe '.send', ->

    beforeEach ->
      @dialogue = new Dialogue @res

    context 'with config.sendReplies set to false', ->

      beforeEach ->
        wait = pretend.observer.next()
        @dialogue.send 'test'
        wait

      it 'sends to the room from original res', ->
        pretend.messages.pop().should.eql [ 'hubot', 'test' ]

    context 'with config.sendReplies set to true', ->

      beforeEach (done) ->
        wait = pretend.observer.next()
        @dialogue.config.sendReplies = true
        @dialogue.send 'test'
        wait

      it 'sends to the room from original res, responding to the @user', ->
        pretend.messages.pop().should.eql ['hubot', '@tester test' ]

  describe '.record', ->

    beforeEach ->
      @match = sinon.spy()
      @mismatch = sinon.spy()
      @dialogue.on 'match', @match
      @dialogue.on 'mismatch', @mismatch
      @key = @dialogue.path
        prompt: 'Turn left or right?'
        branches: [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        key: 'which-way'
        error: 'Bzz. Left or right only!'

    context 'with arguments from the sent prompt', ->

      it 'adds match type, "bot" and content to transcript', ->
        @dialogue.paths[@key].transcript[0].should.eql [
          'send'
          'bot'
          'Turn left or right?'
        ]

    context 'with arguments from a matched choice', ->

      beforeEach ->
        @tester.send 'left'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'match'
          @rec.message.user
          'left'
        ]

      it 'emits mismatch event with user, content', ->
        @match.should.have.calledWith @rec.message.user, 'left'

    context 'with arguments from a mismatched choice', ->

      beforeEach ->
        @tester.send 'up'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'mismatch'
          @rec.message.user
          'up'
        ]

      it 'emits mismatch event with user, content', ->
        @mismatch.should.have.calledWith @rec.message.user, 'up'

  describe '.end', ->

    beforeEach ->
      @dialogue = new Dialogue @res
      @robot.hear /.*/, (res) => @dialogue.receive res # hear all
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
        @dialogue.clearTimeout.should.have.calledOnce

    context 'when triggered by last branch match', ->

      beforeEach ->
        @tester.send '1'

      it 'emits end event with unsuccessful status', ->
        @end.should.have.calledWith true

      it 'sets ended to true', ->
        @dialogue.ended.should.be.true

      it 'clears the timeout only once (from match)', ->
        @dialogue.clearTimeout.should.have.calledOnce

    context 'when already ended (by last branch match)', ->

      beforeEach ->
        @tester.send '1'
        .then => @result = @dialogue.end()

      it 'should not process consecutively', ->
        @result.should.be.false

      it 'should only emit end event once', ->
        @end.should.have.calledOnce

  describe '.onTimeout', ->

    context 'default method', ->

      beforeEach ->
        @dialogue = new Dialogue @res, timeout: 1000
        @dialogue.startTimeout()
        @clock.tick 1000

      it 'sends timeout message to room', ->
        pretend.messages.pop().should.eql [
          'hubot', @dialogue.config.timeoutText
        ]

    context 'method override (as argument)', ->

      beforeEach ->
        @newTimeout = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @oldTimeout = @dialogue.onTimeout
        @dialogue.onTimeout @newTimeout
        @dialogue.startTimeout()
        @clock.tick 1000

      afterEach ->
        @dialogue.onTimeout = @oldTimeout

      it 'calls the override method', ->
        @newTimeout.should.have.calledOnce

      it 'does not send the default timeout message', ->
        pretend.messages.pop().should.not.eql [
          'hubot', @dialogue.config.timeoutText
        ]

    context 'method override (by assignment)', ->

      beforeEach ->
        @newTimeout = sinon.spy()
        @dialogue = new Dialogue @res, timeout: 1000
        @oldTimeout = @dialogue.onTimeout
        @dialogue.onTimeout = @newTimeout
        @dialogue.startTimeout()
        @clock.tick 1000

      afterEach ->
        @dialogue.onTimeout = @oldTimeout

      it 'calls the override method', ->
        @newTimeout.should.have.calledOnce

    context 'method override with invalid function', ->

      beforeEach ->
        @dialogue = new Dialogue @res, timeout: 1000
        @oldTimeout = @dialogue.onTimeout
        @dialogue.onTimeout -> throw new Error "Test exception"
        @override = sinon.spy @dialogue, 'onTimeout'
        @dialogue.startTimeout()
        @clock.tick 1000

      afterEach ->
        @dialogue.onTimeout = @oldTimeout

      it 'throws exception (caught by timeout)', ->
        @override.should.have.threw

      it 'continues to execute and end', ->
        @dialogue.end.should.have.called
