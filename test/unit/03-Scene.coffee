# credit to lmarkus/hubot-conversation for the original concept

Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper '../scripts/ping.coffee'
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'
Helpers = require '../../src/modules/Helpers'

matchAny = new RegExp /.*/

describe '#Scene', ->

  # create room and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'

    # store and log all responses sent and messages received
    @robot = @room.robot
    @robot.on 'receive', (@rec,txt) => @robot.logger.debug "Bot receives: " +txt
    @robot.on 'respond', (@res,txt) => @robot.logger.debug "Bot responds: " +txt
    @robot.logger.info = @robot.logger.debug = -> # silence

    # spy on all the class and helper methods
    _.map _.keys(Scene.prototype), (key) -> sinon.spy Scene.prototype, key
    _.map _.keys(Helpers), (key) -> sinon.spy Helpers, key

    # trigger first response
    @room.user.say 'tester', 'hubot ping'

  afterEach ->
    _.map _.keys(Scene.prototype), (key) -> Scene.prototype[key].restore()
    _.map _.keys(Helpers), (key) -> Helpers[key].restore()
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
      @scene = new Scene @robot, 'user'
      @robot.hear matchAny, (@res) => null # get any response for comparison
      @robotHear = sinon.spy @robot, 'hear' # spy any further hears
      @robotRespond = sinon.spy @robot, 'respond' # spy any further responds

    context 'with hear type and message matching regex', ->

      beforeEach ->
        callback = @callback = sinon.spy()
        @id = @scene.listen 'hear', /test/, (res) -> callback @, res
        @room.user.say 'tester', 'test'
        Q.delay 15

      it 'registers a robot hear listener with regex, id and callback', ->
        @robotHear.should.be.calledWith /test/, id: @id, sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'callback should receive res and "this" should be Dialogue', ->
        @callback.should.have.calledWith sinon.match.instanceOf(Dialogue), @res

    context 'with respond type and message matching regex', ->

      beforeEach ->
        callback = @callback = sinon.spy()
        @id = @scene.listen 'respond', /test/, (res) -> callback @, res
        @room.user.say 'tester', 'hubot test'
        Q.delay 15

      it 'registers a robot respond listener with regex, id and callback', ->
        @robotRespond.should.have.calledWith /test/, id: @id, sinon.match.func

      it 'calls the given callback from listener', ->
        @callback.should.have.calledOnce

      it 'callback should receive res and "this" should be Dialogue', ->
        @callback.should.have.calledWith sinon.match.instanceOf(Dialogue), @res

    context 'without an id string', ->

      beforeEach ->
        @id = @scene.listen 'hear', /test/, -> null

      it 'creates an id with scene and listener scope', ->
        Helpers.keygen.should.have.calledWith @scene.id + '_listener'

      it 'returns the generated id', ->
        @id.should.equal Helpers.keygen.returnValues.pop()

    context 'with an id string', ->

      beforeEach ->
        @id = @scene.listen 'hear', /test/, 'foo', -> null

      it 'creates an id with scene, listener scope and key string', ->
        Helpers.keygen.should.have.calledWith @scene.id + '_listener', 'foo'

    context 'with an invalid type', ->

      beforeEach ->
        try @listenID = @scene.listen 'smell', /test/, -> null

      it 'trhows an error', ->
        @scene.listen.should.have.threw

    context 'with an invalid regex', ->

      beforeEach ->
        try @listenID = @scene.listen 'hear', 'test', -> null

      it 'trhows an error', ->
        @scene.listen.should.have.threw

    context 'with an invalid callback', ->

      beforeEach ->
        try @listenID = @scene.listen 'hear', /test/, { not: 'a function '}

      it 'trhows an error', ->
        @scene.listen.should.have.threw

  describe '.hear', ->

    beforeEach ->
      @scene = new Scene @robot, 'user'
      @scene.hear /test/, -> null

    it 'calls .listen with hear listen type and arguments', ->
      args = ['hear', /test/, sinon.match.func]
      @scene.listen.getCall(0).should.have.calledWith args...

  describe '.respond', ->

    beforeEach ->
      @scene = new Scene @robot, 'user'
      @scene.respond /test/, -> null

    it 'calls .listen with respond listen type and arguments', ->
      args = ['respond', /test/, sinon.match.func]
      @scene.listen.getCall(0).should.have.calledWith args...

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
        @dialogue.branch matchAny, ''

      it 'calls .exit first on "timeout"', ->
        @scene.exit.getCall(0).should.have.calledWith @res, 'timeout'

      it 'calls .exit again on "incomplete"', ->
        @scene.exit.getCall(1).should.have.calledWith @res, 'incomplete'

    # TODO: fix this test - broken by changing Dialogue.send to use @lastRes
    # context 'dialogue completed (by message matching branch)', ->
    #
    #   beforeEach ->
    #     @scene = new Scene @robot
    #     @dialogue = @scene.enter @res
    #     @dialogue.branch matchAny, '' # match anything
    #     @room.user.say 'tester', 'test'
    #     .then => @room.user.say 'tester', 'testing again'
    #
    #   it 'calls .exit once with "complete"', ->
    #     @scene.exit.should.have.calledWith @res, 'complete'
    #
    #   it 'dialogue not continue receiving after scene exit', ->
    #     @scene.middleware.should.have.called

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
        @dialogue.branch matchAny, '' # starts timeout
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
        @dialogue.branch matchAny, '' # starts timeout

      it 'gets called twice (on timeout and end)', ->
        @scene.exit.should.have.calledTwice

      it 'returns true the first time', ->
        @scene.exit.getCall(0).should.have.returned true

      it 'returns false the second time (because already disengaged)', ->
        @scene.exit.getCall(1).should.have.returned false

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
        @room.user.say 'testerA', 'hubot ping' # trigger 1st response
        .then => @dialogueA = @scene.enter @res
        .then => @room.user.say 'testerB', 'hubot ping' # trigger 2nd response
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
