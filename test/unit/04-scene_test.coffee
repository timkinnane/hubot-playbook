sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
co = require 'co'
_ = require 'lodash'
pretend = require 'hubot-pretend'
Dialogue = require '../../lib/modules/dialogue.js'
Scene = require '../../lib/modules/scene.js'

describe 'Scene', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'
    @tester = pretend.user 'tester', id:'tester', room: 'testing'
    @clock = sinon.useFakeTimers()

    Object.getOwnPropertyNames(Scene.prototype).map (key) ->
      sinon.spy Scene.prototype, key

    # generate a response object for starting dialogues
    pretend.robot.hear /test/, -> # listen to tests
    pretend.user('tester').send 'test'
    .then => @res = pretend.lastListen()

  afterEach ->
    pretend.shutdown()
    @clock.restore()

    Object.getOwnPropertyNames(Scene.prototype).map (key) ->
      Scene.prototype[key].restore()

  describe 'constructor', ->

    context 'without options', ->

      beforeEach ->
        @scene = new Scene pretend.robot

      it 'defaults to `user` scope', ->
        @scene.config.scope.should.equal 'user'

      it 'attaches the receive middleware to robot', ->
        pretend.robot.receiveMiddleware.should.have.calledOnce

    context 'with options', ->

      beforeEach ->
        @scene = new Scene pretend.robot, sendReplies: true

      it 'stored options in config object', ->
        @scene.config.sendReplies.should.be.true

    context 'with room scope option', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'room'

      it 'accepts given room scope', ->
        @scene.config.scope.should.equal 'room'

      it 'stores config with default options for scope', ->
        @scene.config.sendReplies.should.be.true

    context 'with invalid scope', ->

      beforeEach ->
        try @scene = new Scene pretend.robot, scope: 'monkey'

      it 'throws error when given invalid scope', ->
        Scene.prototype.constructor.should.have.threw

  describe '.listen', ->

    beforeEach ->
      @scene = new Scene pretend.robot, scope: 'user'

    context 'with hear type and message matching regex', ->

      beforeEach ->
        @callback = sinon.spy()
        @scene.listen 'hear', /test/, @callback
        @tester.send 'test'

      it 'registers a robot hear listener with scene as attribute', ->
        pretend.robot.hear.should.have.calledWithMatch sinon.match.regexp
        , sinon.match.has 'scene', @scene
        , sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'callback should receive res and dialogue', ->
        matchRes = sinon.match.instanceOf pretend.robot.Response
        .and sinon.match.has 'dialogue'
        @callback.should.have.calledWith matchRes

    context 'with respond type and message matching regex', ->

      beforeEach ->
        @callback = sinon.spy()
        @id = @scene.listen 'respond', /test/, @callback
        @tester.send 'hubot test'

      it 'registers a robot respond listener with scene as attribute', ->
        pretend.robot.respond.should.have.calledWithMatch sinon.match.regexp
        , sinon.match.has 'scene', @scene
        , sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'callback should receive res and dialogue', ->
        matchRes = sinon.match.instanceOf pretend.robot.Response
        .and sinon.match.has 'dialogue'
        @callback.should.have.calledWith matchRes

    context 'with an invalid type', ->

      beforeEach ->
        try @scene.listen 'smell', /test/, -> null

      it 'throws', ->
        @scene.listen.should.have.threw

    context 'with an invalid regex', ->

      beforeEach ->
        try @scene.listen 'hear', 'test', -> null

      it 'throws', ->
        @scene.listen.should.have.threw

    context 'with an invalid callback', ->

      beforeEach ->
        try @scene.listen 'hear', /test/, { not: 'a function '}

      it 'throws', ->
        @scene.listen.should.have.threw

  describe '.hear', ->

    beforeEach ->
      @scene = new Scene pretend.robot
      @scene.hear /test/, -> null

    it 'calls .listen with hear listen type and arguments', ->
      args = ['hear', /test/, sinon.match.func]
      @scene.listen.getCall(0).should.have.calledWith args...

  describe '.respond', ->

    beforeEach ->
      @scene = new Scene pretend.robot
      @scene.respond /test/, -> null

    it 'calls .listen with respond listen type and arguments', ->
      args = ['respond', /test/, sinon.match.func]
      @scene.listen.getCall(0).should.have.calledWith args...

  describe '.whoSpeaks', ->

    context 'user scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'user'
        @scene.whoSpeaks @res

      it 'returns the ID of engaged user', ->
        @scene.whoSpeaks.returnValues.pop().should.equal 'tester'

    context 'room sceene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'room'
        @scene.whoSpeaks @res

      it 'returns the room ID', ->
        @scene.whoSpeaks.returnValues.pop().should.equal 'testing'

    context 'direct scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'direct'
        @scene.whoSpeaks @res

      it 'returns the concatenated user ID and room ID', ->
        @scene.whoSpeaks.returnValues.pop().should.equal 'tester_testing'

  describe '.enter', ->

    context 'user scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'user'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with user ID', ->
        @scene.engaged['tester'].should.be.instanceof Dialogue

    context 'room scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'room'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with room key', ->
        @scene.engaged['testing'].should.be.instanceof Dialogue

    context 'direct scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'direct'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with composite key', ->
        @scene.engaged['tester_testing'].should.be.instanceof Dialogue

    context 'with timeout options', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @dialogue = @scene.enter @res,
          timeout: 100
          timeoutText: 'foo'

      it 'passes the options to dialogue config', ->
        @dialogue.config.timeout.should.equal 100
        @dialogue.config.timeoutText.should.equal 'foo'

    context 'dialogue allowed to timeout after branch added', ->

      beforeEach (done) ->
        @scene = new Scene pretend.robot
        @dialogue = @scene.enter @res,
          timeout: 10,
          timeoutText: null
        @dialogue.on 'end', -> done()
        @dialogue.startTimeout()
        @clock.tick 11

      it 'calls .exit first on "timeout"', ->
        @scene.exit.getCall(0).should.have.calledWith @res, 'timeout'

      it 'calls .exit again on "incomplete"', ->
        @scene.exit.getCall(1).should.have.calledWith @res, 'incomplete'

    context 'dialogue completed (by message matching branch)', ->

      beforeEach -> co =>
        @scene = new Scene pretend.robot
        @dialogue = @scene.enter @res
        @dialogue.addBranch /.*/, '' # match anything
        yield @tester.send 'test'
        yield @tester.send 'testing again'

      it 'calls .exit once only', ->
        @scene.exit.should.have.calledOnce

      it 'calls .exit once with last (matched) res and "complete"', ->
        @scene.exit.should.have.calledWith @dialogue.res, 'complete'

    context 're-enter currently engaged participants', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @scene.enter @res
        @scene.enter @res

      it 'returns undefined the second time', ->
        should.not.exist @scene.enter.returnValues[1]

    context 're-enter previously engaged participants', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @dialogueA = @scene.enter @res
        @scene.exit @res # no reason given
        @dialogueB = @scene.enter @res

      it 'returns Dialogue instance (as per normal)', ->
        @dialogueB.should.be.instanceof Dialogue

  describe '.exit', ->

    context 'with user in scene, called manually', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @dialogue = @scene.enter @res, timeout: 10
        @dialogue.addBranch /.*/, '' # starts timeout
        @timeout = sinon.spy()
        @dialogue.onTimeout @timeout
        @dialogue.receive = sinon.spy()
        @scene.exit @res, 'tester'
        @tester.send 'test'
        @clock.tick 11

      it 'does not call onTimeout on dialogue', ->
        @timeout.should.not.have.called

      it 'removes the dialogue instance from engaged array', ->
        should.not.exist @scene.engaged['tester']

      it 'returns true', ->
        @scene.exit.returnValues.pop().should.be.true

      it 'dialogue does not continue receiving after scene exit', ->
        @dialogue.receive.should.not.have.called

    context 'with user in scene, called from events', ->

      beforeEach (done) ->
        @scene = new Scene pretend.robot
        @dialogue = @scene.enter @res, timeout: 10
        @dialogue.on 'end', -> done()
        @dialogue.addBranch /.*/, '' # starts timeout
        @clock.tick 11

      it 'gets called twice (on timeout and end)', ->
        @scene.exit.should.have.calledTwice

      it 'returns true the first time', ->
        @scene.exit.getCall(0).should.have.returned true

      it 'returns false the second time (because already disengaged)', ->
        @scene.exit.getCall(1).should.have.returned false

    context 'user not in scene, called manually', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @scene.exit @res, 'tester'

      it 'returns false', ->
        @scene.exit.returnValues.pop().should.be.false

  describe '.exitAll', ->

    context 'with two users in scene', ->

      beforeEach -> co =>
        @scene = new Scene pretend.robot
        yield pretend.user('A').send 'test'
        @dialogueB = @scene.enter pretend.lastListen()
        yield pretend.user('B').send 'test'
        @dialogueA = @scene.enter pretend.lastListen()
        @dialogueA.clearTimeout = sinon.spy()
        @dialogueB.clearTimeout = sinon.spy()
        @scene.exitAll()

      it 'created two dialogues', ->
        @dialogueA.should.be.instanceof Dialogue
        @dialogueB.should.be.instanceof Dialogue

      it 'calls clearTimeout on both dialogues', ->
        @dialogueA.clearTimeout.should.have.calledOnce
        @dialogueB.clearTimeout.should.have.calledOnce

      it 'has no remaining engaged dialogues', ->
        @scene.engaged.length.should.equal 0

  describe '.getDialogue', ->

    context 'with user in scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @dialogueA = @scene.enter @res
        @dialogueB = @scene.getDialogue 'tester'

      it 'returns the matching dialogue', ->
        @dialogueB.should.eql @dialogueA

    context 'no user in scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @dialogue = @scene.getDialogue 'tester'

      it 'returns undefined', ->
        should.not.exist @dialogue

  describe '.inDialogue', ->

    context 'in engaged user scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @scene.enter @res
        @userEngaged = @scene.inDialogue 'tester'
        @roomEngaged = @scene.inDialogue 'testing'

      it 'returns true with user ID', ->
        @userEngaged.should.be.true

      it 'returns false with room name', ->
        @roomEngaged.should.be.false

    context 'no participants in scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot
        @userEngaged = @scene.inDialogue 'tester'

      it 'returns false', ->
        @userEngaged.should.be.false

    context 'room scene, in scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'room'
        @scene.enter @res
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'

      it 'returns true with roomname', ->
        @roomEngaged.should.be.true

      it 'returns false with user ID', ->
        @userEngaged.should.be.false

    context 'direct scene, in scene', ->

      beforeEach ->
        @scene = new Scene pretend.robot, scope: 'direct'
        @scene.enter @res
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'
        @directEngaged = @scene.inDialogue 'tester_testing'

      it 'returns true with userID_roomID', ->
        @directEngaged.should.be.true

      it 'returns false with roomname', ->
        @roomEngaged.should.be.false

      it 'returns false with user ID', ->
        @userEngaged.should.be.false
