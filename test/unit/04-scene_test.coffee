util = require 'util'
_ = require 'lodash'
co = require 'co'
chai = require 'chai'
sinon = require 'sinon'

should = chai.should()
chai.use require 'sinon-chai'
pretend = require 'hubot-pretend'
Dialogue = require '../../lib/modules/dialogue'
Scene = require '../../lib/modules/scene'

setImmediatePromise = util.promisify setImmediate

wait = (delay) -> new Promise (resolve, reject) -> setTimeout resolve, delay
matchRes = null
matchAny = /.*/

describe 'Scene', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'

    matchRes = sinon.match.instanceOf pretend.robot.Response
    .and sinon.match.has 'dialogue'

    Object.getOwnPropertyNames(Scene.prototype).map (key) ->
      sinon.spy Scene.prototype, key

  afterEach ->
    pretend.shutdown()

    Object.getOwnPropertyNames(Scene.prototype).map (key) ->
      Scene.prototype[key].restore()

  describe 'constructor', ->

    context 'without options', ->

      it 'defaults to `user` scope', ->
        scene = new Scene pretend.robot
        scene.config.scope.should.equal 'user'

      it 'attaches receive middleware to robot', ->
        new Scene pretend.robot
        pretend.robot.receiveMiddleware.should.have.calledOnce

    context 'with options', ->

      it 'stored options in config object', ->
        scene = new Scene pretend.robot, sendReplies: true
        scene.config.sendReplies.should.be.true

    context 'with room scope option', ->

      it 'accepts given room scope', ->
        scene = new Scene pretend.robot, scope: 'room'
        scene.config.scope.should.equal 'room'

      it 'stores config with default options for scope', ->
        scene = new Scene pretend.robot, scope: 'room'
        scene.config.sendReplies.should.be.true

    context 'with invalid scope', ->

      it 'throws error when given invalid scope', ->
        try new Scene pretend.robot, scope: 'monkey'
        Scene.prototype.constructor.should.throw

  describe '.listen', ->

    it 'accepts a string that can be cast as RegExp', ->
      scene = new Scene pretend.robot
      scene.listen 'hear', '/test/i', () -> null
      pretend.robot.listeners.pop().regex.should.eql /test/i

    context 'with hear type and message matching regex', ->

      it 'registers a robot hear listener with same id as scene', ->
        scene = new Scene pretend.robot
        scene.listen 'hear', /test/, () -> null
        pretend.robot.hear.should.have.calledWithMatch sinon.match.regexp
        , sinon.match({ id: scene.id })
        , sinon.match.func

      it 'calls callback from listener when matched', -> co ->
        scene = new Scene pretend.robot
        callback = sinon.spy()
        scene.listen 'hear', /test/, callback
        yield pretend.user('tester').send 'test'
        callback.should.have.calledOnce

      it 'callback should receive res and dialogue', ->
        scene = new Scene pretend.robot
        callback = sinon.spy()
        scene.listen 'hear', /test/, callback
        pretend.user('tester').send 'test'
        .then ->
          callback.should.have.calledWith matchRes

    context 'with respond type and message matching regex', ->

      it 'registers a robot hear listener with same id as scene', ->
        scene = new Scene pretend.robot
        callback = sinon.spy()
        id = scene.listen 'respond', /test/, callback
        pretend.user('tester').send 'hubot test'
        .then ->
          pretend.robot.respond.should.have.calledWithMatch sinon.match.regexp
          , sinon.match({ id: scene.id })
          , sinon.match.func

      it 'calls callback from listener when matched', -> co ->
        scene = new Scene pretend.robot
        callback = sinon.spy()
        id = scene.listen 'respond', /test/, callback
        yield pretend.user('tester').send 'hubot test'
        callback.should.have.calledOnce

      it 'callback should receive res and dialogue', -> co ->
        scene = new Scene pretend.robot
        callback = sinon.spy()
        id = scene.listen 'respond', /test/, callback
        yield pretend.user('tester').send 'hubot test'
        callback.should.have.calledWith matchRes

    context 'with an invalid listener type', ->

      it 'throws', ->
        scene = new Scene pretend.robot
        try scene.listen 'smell', /test/, -> null
        scene.listen.should.throw

    context 'with an invalid regex', ->

      it 'throws', ->
        scene = new Scene pretend.robot
        try scene.listen 'hear', 'test', -> null
        scene.listen.should.throw

    context 'with an invalid callback', ->

      it 'throws', ->
        scene = new Scene pretend.robot
        try scene.listen 'hear', /test/, { not: 'a function '}
        scene.listen.should.throw

  describe '.hear', ->

    it 'calls .listen with hear listen type and arguments', ->
      scene = new Scene pretend.robot
      scene.hear /test/, -> null
      expectedArgs = ['hear', /test/, sinon.match.func]
      scene.listen.getCall(0).should.have.calledWith expectedArgs...

  describe '.respond', ->

    it 'calls .listen with respond listen type and arguments', ->
      scene = new Scene pretend.robot
      scene.respond /test/, -> null
      expectedArgs = ['respond', /test/, sinon.match.func]
      scene.listen.getCall(0).should.have.calledWith expectedArgs...

  describe '.whoSpeaks', ->

    beforeEach ->
      pretend.user('tester', { id: 'user_111', room: 'testing' }).send('test')

    context 'user scene', ->

      it 'returns the ID of engaged user', ->
        scene = new Scene pretend.robot, scope: 'user'
        scene.whoSpeaks pretend.lastReceive()
        .should.equal 'user_111'

    context 'room sceene', ->

      it 'returns the room ID', ->
        scene = new Scene pretend.robot, scope: 'room'
        scene.whoSpeaks pretend.lastReceive()
        .should.equal 'testing'

    context 'direct scene', ->

      it 'returns the concatenated user ID and room ID', ->
        scene = new Scene pretend.robot, scope: 'direct'
        scene.whoSpeaks pretend.lastReceive()
        .should.equal 'user_111_testing'

  describe '.registerMiddleware', ->

    it 'accepts function for enter middleware stack', ->
      piece = (context, next, done) -> null
      scene = new Scene pretend.robot
      scene.registerMiddleware piece
      scene.enterMiddleware.stack[0].should.eql piece

    it 'throws when given function with incorrect arguments', ->
      piece = (notEnoughArgs) -> null
      scene = new Scene pretend.robot
      try scene.registerMiddleware piece
      scene.registerMiddleware.should.throw
      scene.enterMiddleware.stack.length.should.equal 0

  describe '.enter', ->

    beforeEach ->
      pretend.user('tester', { id: 'user_111', room: 'testing' }).send('test')

    it 'returns a promise (then-able)', ->
      scene = new Scene pretend.robot
      promise = scene.enter pretend.lastReceive()
      promise.then.should.be.a 'function'

    it 'calls .processEnter with context', -> co ->
      scene = new Scene pretend.robot
      yield scene.enter pretend.lastReceive()
      scene.processEnter.should.have.calledOnce

    it 'resolves after callback called', -> co ->
      scene = new Scene pretend.robot
      callback = sinon.spy()
      result = yield scene.enter pretend.lastReceive(), callback
      callback.should.have.calledOnce

    it 'exits (after event loop) if no dialogue paths added', -> co ->
      scene = new Scene pretend.robot
      yield scene.enter pretend.lastReceive()
      yield setImmediatePromise() # wait for start of next event loop
      scene.exit.should.have.calledWith pretend.lastReceive(), 'no path'

    it 'can use dialogue after yielding to prevent exit', -> co ->
      scene = new Scene pretend.robot
      context = yield scene.enter pretend.lastReceive()
      context.dialogue.addBranch matchAny, ''
      yield setImmediatePromise()
      scene.exit.should.not.have.called

    context 'with callback (no middleware)', ->

      it 'calls callback with final enter process context', (done) ->
        scene = new Scene pretend.robot
        keys = ['response', 'participants', 'options', 'arguments', 'dialogue']
        callback = (result) ->
          result.should.have.all.keys keys...
          done()
        scene.enter pretend.lastReceive(), callback
        return

    context 'with passing middleware', ->

      it 'completes processing to resolve with context', -> co ->
        scene = new Scene pretend.robot
        keys = ['response', 'participants', 'options', 'arguments', 'dialogue']
        scene.registerMiddleware (context, next, done) -> next()
        result = yield scene.enter pretend.lastReceive()
        result.should.have.all.keys keys...

      it 'calls callback with final enter process context', (done) ->
        scene = new Scene(pretend.robot)
        keys = ['response', 'participants', 'options', 'arguments', 'dialogue']
        callback = (result) ->
          result.should.have.all.keys keys...
          done()
        scene.registerMiddleware (context, next, done) -> next()
        scene.enter pretend.lastReceive(), callback
        return

    context 'with blocking middleware', ->

      it 'rejects promise', ->
        scene = new Scene pretend.robot
        scene.registerMiddleware (context, next, done) -> done()
        scene.enter(pretend.lastReceive())
        .then () -> throw new Error 'promise should have caught'
        .catch (err) ->
          err.should.be.instanceof Error
          err.should.have.property 'message', 'Middleware piece called done'

      it 'does not complete or call .processEnter', -> co ->
        scene = new Scene pretend.robot
        scene.registerMiddleware (context, next, done) -> done()
        try yield scene.enter pretend.lastReceive()
        catch error
        scene.processEnter.should.not.have.called

    context 'with custom done function override', ->

      it 'completes processing and calls custom done', -> co ->
        scene = new Scene pretend.robot
        custom = sinon.spy()
        scene.registerMiddleware (context, next, done) -> next () ->
          custom()
          done()
        yield scene.enter pretend.lastReceive()
        custom.should.have.calledOnce

    context 'with multiple middleware pieces', ->

      it 'calls each sequentially passing ammended context', (done) ->
        scene = new Scene pretend.robot
        scene.registerMiddleware (context, next, done) ->
          context.trace = ['A']
          next()
        scene.registerMiddleware (context, next, done) ->
          context.trace.push('B')
          next()
        scene.registerMiddleware (context, next, done) ->
          context.trace.push('C')
          next()
        scene.enter pretend.lastReceive(), (result) ->
          result.trace.should.eql ['A', 'B', 'C']
          done()
        return

      it 'does not process enter if any middleware blocks', -> co ->
        scene = new Scene pretend.robot
        scene.registerMiddleware (context, next, done) -> next()
        scene.registerMiddleware (context, next, done) -> done()
        scene.registerMiddleware (context, next, done) -> next()
        try yield scene.enter pretend.lastReceive()
        catch error
        scene.processEnter.should.not.have.called

    context 'user scene', ->

      it 'saves engaged Dialogue instance with user ID', -> co ->
        scene = new Scene pretend.robot, scope: 'user'
        yield scene.enter pretend.lastReceive()
        scene.engaged['user_111'].should.be.instanceof Dialogue

    context 'room scene', ->

      it 'saves engaged Dialogue instance with room key', -> co ->
        scene = new Scene pretend.robot, scope: 'room'
        yield scene.enter pretend.lastReceive()
        scene.engaged['testing'].should.be.instanceof Dialogue

    context 'direct scene', ->

      it 'saves engaged Dialogue instance with composite key', -> co ->
        scene = new Scene pretend.robot, scope: 'direct'
        yield scene.enter pretend.lastReceive()
        scene.engaged['user_111_testing'].should.be.instanceof Dialogue

    context 'with timeout options', ->

      it 'passes the options to dialogue config', ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive(),
          timeout: 100
          timeoutText: 'foo'
        dialogue.config.timeout.should.equal 100
        dialogue.config.timeoutText.should.equal 'foo'

    context 'dialogue allowed to timeout after branch added', ->

      it 'calls .exit first on "timeout"', (done) ->
        scene = new Scene pretend.robot
        res = pretend.lastReceive()
        scene.enter res,
          timeout: 10,
          timeoutText: null
        .then (context) ->
          context.dialogue.on 'end', ->
            scene.exit.should.have.calledWith res, 'timeout'
            done()
          context.dialogue.addBranch matchAny, '' # start timeout, stop exit
          wait 20
        return

      it 'calls .exit again on "incomplete"', (done) ->
        scene = new Scene pretend.robot
        res = pretend.lastReceive()
        scene.enter res,
          timeout: 10,
          timeoutText: null
        .then (context) ->
          context.dialogue.on 'end', ->
            scene.exit.should.have.calledWith res, 'incomplete'
            done()
          context.dialogue.addBranch matchAny, ''
          wait 20
        return

    context 'dialogue completed (by message matching branch)', ->

      it 'calls .exit once only', -> co ->
        scene = new Scene pretend.robot
        context = yield scene.enter pretend.lastReceive()
        context.dialogue.addBranch matchAny, ''
        yield pretend.user('tester').send 'test'
        yield pretend.user('tester').send 'testing again'
        scene.exit.should.have.calledOnce

      it 'calls .exit once with last (matched) res and "complete"', -> co ->
        scene = new Scene pretend.robot
        context = yield scene.enter pretend.lastReceive()
        context.dialogue.addBranch matchAny, ''
        yield pretend.user('tester').send 'test'
        yield pretend.user('tester').send 'testing again'
        scene.exit.should.have.calledWith context.dialogue.res, 'complete'

    context 're-enter currently engaged participants', ->

      it 'returns error the second time', -> co ->
        scene = new Scene pretend.robot
        resultA = yield scene.enter pretend.lastReceive()
        try resultB = yield scene.enter pretend.lastReceive()
        scene.enter.should.throw

      it 'rejected enter can be caught', (done) ->
        scene = new Scene pretend.robot
        scene.enter pretend.lastReceive()
        .then ->
          scene.enter pretend.lastReceive()
          .catch (err) ->
            err.should.be.instanceof Error
            done()
        return

    context 're-enter previously engaged participants', ->

      it 'returns Dialogue instance (as per normal)', -> co ->
        scene = new Scene pretend.robot
        yield scene.enter pretend.lastReceive()
        scene.exit pretend.lastReceive() # no reason given
        {dialogue} = yield scene.enter pretend.lastReceive()
        dialogue.should.be.instanceof Dialogue

  describe '.exit', ->

    beforeEach ->
      pretend.user('tester', { id: 'user_111', room: 'testing' }).send('test')

    context 'with user in scene, called manually', ->

      it 'does not call onTimeout on dialogue', -> co ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive(), timeout: 10
        dialogue.addBranch matchAny, '' # start timeout, stop exit
        timeout = sinon.spy()
        dialogue.onTimeout timeout
        scene.exit pretend.lastReceive(), 'testing exits'
        yield wait 20
        timeout.should.not.have.called

      it 'removes the dialogue instance from engaged array', -> co ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive(), timeout: 10
        dialogue.addBranch matchAny, '' # start timeout, stop exit
        scene.exit pretend.lastReceive(), 'testing exits'
        should.not.exist scene.engaged['user_111']

      it 'returns true', -> co ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive(), timeout: 10
        dialogue.addBranch matchAny, '' # start timeout, stop exit
        scene.exit pretend.lastReceive(), 'testing exits'
        yield wait 20
        scene.exit.returnValues.pop().should.be.true

      it 'logged the reason', -> co ->
        scene = new Scene pretend.robot
        scene.id = 'scene_111'
        {dialogue} = yield scene.enter pretend.lastReceive(), timeout: 10
        dialogue.addBranch matchAny, '' # start timeout, stop exit
        scene.exit pretend.lastReceive(), 'testing exits'
        yield wait 20
        pretend.logs.pop().should.eql [
          'info', 'Disengaged user user_111 (testing exits) (id: scene_111)'
        ]

      it 'dialogue does not continue receiving after scene exit', -> co ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive(), timeout: 10
        dialogue.addBranch matchAny, '' # start timeout, stop exit
        dialogue.receive = sinon.spy()
        scene.exit pretend.lastReceive(), 'tester'
        pretend.user('tester').send 'test'
        yield wait 20
        dialogue.receive.should.not.have.called

    context 'with user in scene, called from events', ->

      it 'gets called twice (on timeout and end)', (done) ->
        scene = new Scene pretend.robot
        scene.enter pretend.lastReceive(), timeout: 10
        .then (context) ->
          context.dialogue.on 'end', ->
            scene.exit.should.have.calledTwice
            done()
          context.dialogue.addBranch matchAny, '' # start timeout, stop exit
          wait 20
        return

      it 'returns true the first time', (done) ->
        scene = new Scene pretend.robot
        scene.enter pretend.lastReceive(), timeout: 10
        .then (context) ->
          context.dialogue.on 'end', ->
            scene.exit.getCall(0).should.have.returned true
            done()
          context.dialogue.addBranch matchAny, '' # start timeout, stop exit
          wait 20
        return

      it 'returns false the second time (because already disengaged)', (done) ->
        scene = new Scene pretend.robot
        scene.enter pretend.lastReceive(), timeout: 10
        .then (context) ->
          context.dialogue.on 'end', ->
            scene.exit.getCall(1).should.have.returned false
            done()
          context.dialogue.addBranch matchAny, '' # start timeout, stop exit
          wait 20
        return

    context 'user not in scene, called manually', ->

      it 'returns false', ->
        scene = new Scene pretend.robot
        scene.exit pretend.lastReceive(), 'testing exits'
        scene.exit.returnValues.pop().should.be.false

  describe '.exitAll', ->

    context 'with two users in scene', ->

      it 'created two dialogues', -> co ->
        scene = new Scene pretend.robot
        A = yield scene.enter pretend.response 'A', 'test'
        B = yield scene.enter pretend.response 'B', 'test'
        scene.exitAll()
        A.dialogue.should.be.instanceof Dialogue
        B.dialogue.should.be.instanceof Dialogue

      it 'calls clearTimeout on both dialogues', -> co ->
        scene = new Scene pretend.robot
        resA = pretend.response 'A', 'test'
        resB = pretend.response 'B', 'test'
        A = yield scene.enter resA
        A.dialogue.addBranch matchAny, ''
        B = yield scene.enter resB
        B.dialogue.addBranch matchAny, ''
        A.dialogue.clearTimeout = sinon.spy()
        B.dialogue.clearTimeout = sinon.spy()
        scene.exitAll()
        A.dialogue.clearTimeout.should.have.calledOnce
        B.dialogue.clearTimeout.should.have.calledOnce

      it 'has no remaining engaged dialogues', -> co ->
        scene = new Scene pretend.robot
        yield scene.enter pretend.response 'A', 'test'
        yield scene.enter pretend.response 'B', 'test'
        scene.exitAll()
        scene.engaged.length.should.equal 0

  describe '.getDialogue', ->

    beforeEach ->
      pretend.user('tester', { id: 'user_111', room: 'testing' }).send('test')

    context 'with user in scene', ->

      it 'returns the matching dialogue', -> co ->
        scene = new Scene pretend.robot
        {dialogue} = yield scene.enter pretend.lastReceive()
        result = scene.getDialogue 'user_111'
        dialogue.should.eql result

    context 'no user in scene', ->

      it 'returns undefined', ->
        scene = new Scene pretend.robot
        dialogue = scene.getDialogue 'user_111'
        should.not.exist dialogue

  describe '.inDialogue', ->

    beforeEach ->
      pretend.user('tester', { id: 'user_111', room: 'testing' }).send('test')

    context 'in engaged user scene', ->

      it 'returns true with user ID', -> co ->
        scene = new Scene pretend.robot
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'user_111'
        .should.be.true

      it 'returns false with room name', -> co ->
        scene = new Scene pretend.robot
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'testing'
        .should.be.false

    context 'participant not in scene', ->

      it 'returns false', -> co ->
        scene = new Scene pretend.robot
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'user_222'
        .should.be.false

    context 'room scene, in scene', ->

      it 'returns true with roomname', -> co ->
        scene = new Scene pretend.robot, scope: 'room'
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'testing'
        .should.be.true

      it 'returns false with user ID', -> co ->
        scene = new Scene pretend.robot, scope: 'room'
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'user_111'
        .should.be.false

    context 'direct scene, in scene', ->

      it 'returns true with userID_roomID', -> co ->
        scene = new Scene pretend.robot, scope: 'direct'
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'user_111_testing'
        .should.be.true

      it 'returns false with roomname', -> co ->
        scene = new Scene pretend.robot, scope: 'direct'
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'testing'
        .should.be.false

      it 'returns false with user ID', -> co ->
        scene = new Scene pretend.robot, scope: 'direct'
        yield scene.enter pretend.lastReceive()
        scene.inDialogue 'user_111'
        .should.be.false
