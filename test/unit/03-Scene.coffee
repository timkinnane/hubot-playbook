# credit to lmarkus/hubot-conversation for the original concept

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
Scene = require '../../src/modules/Scene'
{keygen} = require '../../src/modules/Helpers'

describe '#Scene', ->

  # create room and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'
    @observer = new Observer @room.messages
    @robot = @room.robot
    @keygen = sinon.spy keygen
    @robot.on 'respond', (res) => @res = res # store every response sent
    @robot.on 'receive', (res) => @rec = res # store every message received
    @robot.logger.info = @robot.logger.debug = -> # silence
    @spy = _.mapObject Scene.prototype, (val, key) ->
      sinon.spy Scene.prototype, key # spy on all the class methods
    @room.user.say 'tester', 'hubot ping' # trigger first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  describe 'constructor', ->

    context 'without type or options', ->

      beforeEach ->
        delete process.env.SEND_REPLIES # prevent interference
        namespace = Scene: require "../../src/modules/Scene"
        @constructor = sinon.spy namespace, 'Scene'
        @scene = new namespace.Scene @robot

      it 'does not throw', ->
        @constructor.should.not.have.threw

      it 'defaults to `user` type', ->
        @scene.type.should.equal 'user'

      it 'attaches the receive middleware to robot', ->
        @robot.middleware.receive.stack.length.should.equal 2
        # length is 2 because of test helper middleware added by ping.coffee

      it 'stores config object with default reply setting', ->
        @scene.config.should.eql { sendReplies: false }

    context 'without type or options, environment overriding reply setting', ->

      beforeEach ->
        process.env.SEND_REPLIES = true
        @scene = new Scene @robot

      afterEach ->
        delete process.env.SEND_REPLIES

      it 'stores config object with overriden reply setting', ->
        @scene.config.should.eql { sendReplies: true }

    context 'without type, with options', ->

      beforeEach ->
        namespace = Scene: require "../../src/modules/Scene"
        @constructor = sinon.spy namespace, 'Scene'
        @scene = new namespace.Scene @robot, sendReplies: true

        it 'does not throw when given options without type', ->
          @constructor.should.not.have.threw

        it 'defaults to user type', ->
          @scene.type.should.equal 'user'

        it 'stored options in config object', ->
          @scene.config.sendReplies.should.be.true

    context 'with type (room), without options', ->

      beforeEach ->
        namespace = Scene: require "../../src/modules/Scene"
        @constructor = sinon.spy namespace, 'Scene'
        @scene = new namespace.Scene @robot, 'room'

      it 'does not throw when given type without options', ->
        @constructor.should.not.have.threw

      it 'accepts given room type', ->
        @scene.type.should.equal 'room'

      it 'stores config with default options for type', ->
        @scene.config.sendReplies.should.be.true

    context 'with invalid type', ->

      beforeEach ->
        namespace = Scene: require "../../src/modules/Scene"
        try
          @constructor = sinon.spy namespace, 'Scene'
          @scene = new namespace.Scene @robot, 'monkey'

      it 'throws error when given invalid type', ->
        @constructor.should.have.threw

  describe '.listen', ->

    beforeEach ->
      callback = @callback = sinon.spy()
      @scene = new Scene @robot, 'user'
      @robot.hear /.*/, (@res) => null # get any response for comparison
      @robotHear = sinon.spy @robot, 'hear' # spy any further listeners
      @robotRespond = sinon.spy @robot, 'respond'

    context 'with hear type and message matching regex', ->

      beforeEach ->
        callback = @callback
        @id = @scene.listen 'hear', /test/, (res) -> callback @, res
        @room.user.say 'tester', 'test'
        Q.delay 15

      it 'registers a robot hear listener with regex, id and callback', ->
        @robotHear.should.be.calledWith /test/, id: @id, sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'creates Dialogue instance, replaces "this" in callback', ->
        @callback.args[0][0].should.be.instanceof Dialogue

      it 'passes response object from listener to callback', ->
        @callback.args[0][1].should.eql @res

    context 'with respond type and message matching regex', ->

      beforeEach ->
        callback = @callback
        @id = @scene.listen 'respond', /test/, (res) -> callback @, res
        @room.user.say 'tester', 'hubot test'
        Q.delay 15

      it 'registers a robot respond listener with regex, id and callback', ->
        @robotRespond.should.be.calledWith /test/, id: @id, sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'creates Dialogue instance, replaces "this" in callback', ->
        @callback.args[0][0].should.be.instanceof Dialogue

      it 'passes response object from listener to callback', ->
        @callback.args[0][1].should.eql @res

    context 'without an id string', ->

      beforeEach ->
        @id = @scene.listen 'hear', /test/, (res) ->

      it 'calls keygen to generate a key', ->
        @keygen.should.have.calledWith()

      it 'stores the listener id, type and regex', ->
        @scene.listeners[0].should.eql
          id: @id
          type: 'hear'
          regex: /test/

      it 'returns the generated id', ->
        @id.should.equal @keygen.returnValues[0]

    context 'with an id string', ->

      beforeEach ->
        @id = @scene.listen 'hear', /test/, 'foo', -> null

      it 'calls keygen with given key string', ->
        @keygen.should.have.calledWith 'foo'

      it 'stores the listener id, type and regex', ->
        @scene.listeners[0].should.eql
          id: 'foo'
          type: 'hear'
          regex: /test/

    context 'with an invalid type', ->

      beforeEach ->
        try @listenID = @scene.listen 'smell', /test/, -> null

      it 'trhows an error', ->
        @spy.listen.should.have.threw

    context 'with an invalid regex', ->

      beforeEach ->
        try @listenID = @scene.listen 'hear', 'test', -> null

      it 'trhows an error', ->
        @spy.listen.should.have.threw

    context 'with an invalid callback', ->

      beforeEach ->
        try @listenID = @scene.listen 'hear', /test/, { not: 'a function '}

      it 'trhows an error', ->
        @spy.listen.should.have.threw

  describe '.hear', ->

    beforeEach ->
      @scene = new Scene @robot, 'user'
      @scene.hear /test/, -> null

    it 'calls .listen with hear listen type and arguments', ->
      args = ['hear', /test/, sinon.match.func]
      @spy.listen.getCall(0).should.have.calledWith args...

  describe '.respond', ->

    beforeEach ->
      @scene = new Scene @robot, 'user'
      @scene.respond /test/, -> null

    it 'calls .listen with respond listen type and arguments', ->
      args = ['respond', /test/, sinon.match.func]
      @spy.listen.getCall(0).should.have.calledWith args...

  describe '.whoSpeaks', ->

    context 'user scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'user'
        @result = @scene.whoSpeaks @res

      it 'returns the username of engaged user', ->
        @result.should.equal 'tester'

    context 'room sceene', ->

      beforeEach ->
        @scene = new Scene @robot, 'room'
        @result = @scene.whoSpeaks @res

      it 'returns the room ID', ->
        @result.should.equal 'testing'

    context 'direct scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'direct'
        @result = @scene.whoSpeaks @res

      it 'returns the concatenated username and room ID', ->
        @result.should.equal 'tester_testing'

  describe '.enter', ->

    context 'user scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'user'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with username key', ->
        @scene.engaged['tester'].should.be.instanceof Dialogue

    context 'room scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'room'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with room key', ->
        @scene.engaged['testing'].should.be.instanceof Dialogue

    context 'direct scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'direct'
        @dialogue = @scene.enter @res

      it 'saves engaged Dialogue instance with composite key', ->
        @scene.engaged['tester_testing'].should.be.instanceof Dialogue

    context 'with timeout options', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res,
          timeout: 100
          timeoutLine: 'foo'

      it 'passes the options to dialogue config', ->
        @dialogue.config.timeout.should.equal 100
        @dialogue.config.timeoutLine.should.equal 'foo'

    context 'dialogue allowed to timeout after branch added', ->

      beforeEach (done) ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res,
          timeout: 10,
          timeoutLine: null
        @dialogue.on 'end', -> done()
        @dialogue.branch /.*/, ''

      it 'calls .exit first on "timeout"', ->
        @spy.exit.getCall(0).should.have.calledWith @res, 'timeout'

      it 'calls .exit again on "incomplete"', ->
        @spy.exit.getCall(1).should.have.calledWith @res, 'incomplete'

    context 'dialogue completed (by message matching branch)', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res
        @dialogue.branch /.*/, '' # match anything
        @room.user.say 'tester', 'test'
        @room.user.say 'tester', 'testing again'

      it 'calls .exit once with "complete"', ->
        @spy.exit.should.have.calledWith @res, 'complete'

      it 'dialogue not continue receiving after scene exit', ->
        @spy.middleware.should.have.called

    context 're-enter currently engaged participants', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogueA = @scene.enter @res
        @dialogueB = @scene.enter @res

      it 'returns null the second time', ->
        should.equal @dialogueB, null

    context 're-enter previously engaged participants', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogueA = @scene.enter @res
        @scene.exit @res # no reason given
        @dialogueB = @scene.enter @res

      it 'returns Dialogue instance (as per normal)', ->
        @dialogueB.should.be.instanceof Dialogue

  describe '.exit', ->

    context 'with user in scene, called manually', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res, timeout: 10
        @dialogue.branch /.*/, '' # starts timeout
        @timeout = sinon.spy()
        @dialogue.onTimeout => @timeout()
        @result = @scene.exit @res, 'testing'
        Q.delay 15

      it 'does not call onTimeout on dialogue', ->
        @timeout.should.not.have.called

      it 'removes the dialogue instance from engaged array', ->
        should.not.exist @scene.engaged['tester']

      it 'returns true', ->
        @result.should.be.true

    context 'with user in scene, called from events', ->

      beforeEach (done) ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res, timeout: 10
        @dialogue.on 'end', -> done()
        @dialogue.branch /.*/, '' # starts timeout

      it 'gets called twice (on timeout and end)', ->
        @spy.exit.should.have.calledTwice

      it 'returns true the first time', ->
        @spy.exit.getCall(0).should.have.returned true

      it 'returns false the second time (because already disengaged)', ->
        @spy.exit.getCall(1).should.have.returned false

    context 'user not in scene, called manually', ->

      beforeEach ->
        @scene = new Scene @robot
        @result = @scene.exit @res, 'testing'

      it 'returns false', ->
        @result.should.be.false

  describe '.exitAll', ->

    context 'with two users in scene', ->

      beforeEach ->
        @scene = new Scene @robot
        @room.user.say 'testerA', 'hubot ping' # trigger new response
        .then => @dialogueA = @scene.enter @res
        .then => @room.user.say 'testerB', 'hubot ping' # trigger second response
        .then => @dialogueB = @scene.enter @res
        .then =>
          @clearA = sinon.spy @dialogueA, 'clearTimeout'
          @clearB = sinon.spy @dialogueB, 'clearTimeout'
          @scene.exitAll()

      it 'created two dialogues', ->
        @dialogueA.should.be.instanceof Dialogue
        @dialogueB.should.be.instanceof Dialogue

      it 'calls clearTimeout on both dialogues', ->
        @clearA.should.have.calledOnce
        @clearB.should.have.calledOnce

      it 'has no remaining engaged dialogues', ->
        @scene.engaged.length.should.equal 0

  describe '.dialogue', ->

    context 'with user in scene', ->

      beforeEach ->
        @scene = new Scene @robot
        @dialogue = @scene.enter @res
        @result = @scene.dialogue 'tester'

      it 'returns the matching dialogue', ->
        @result.should.eql @dialogue

    context 'no user in scene', ->

      beforeEach ->
        @scene = new Scene @robot
        @result = @scene.dialogue 'tester'

      it 'returns null', ->
        should.equal @result, null

  describe '.inDialogue', ->

    context 'in engaged user scene', ->

      beforeEach ->
        @scene = new Scene @robot
        @scene.enter @res
        @userEngaged = @scene.inDialogue 'tester'
        @roomEngaged = @scene.inDialogue 'testing'

      it 'returns true with username', ->
        @userEngaged.should.be.true

      it 'returns false with room name', ->
        @roomEngaged.should.be.false

    context 'no participants in scene', ->

      beforeEach ->
        @scene = new Scene @robot
        @userEngaged = @scene.inDialogue 'tester'

      it 'returns false', ->
        @userEngaged.should.be.false

    context 'room scene, in scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'room'
        @scene.enter @res
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'

      it 'returns true with roomname', ->
        @roomEngaged.should.be.true

      it 'returns false with username', ->
        @userEngaged.should.be.false

    context 'direct scene, in scene', ->

      beforeEach ->
        @scene = new Scene @robot, 'direct'
        @scene.enter @res
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'
        @directEngaged = @scene.inDialogue 'tester_testing'

      it 'returns true with ${username}_${roomID}', ->
        @directEngaged.should.be.true

      it 'returns false with roomname', ->
        @roomEngaged.should.be.false

      it 'returns false with username', ->
        @userEngaged.should.be.false
