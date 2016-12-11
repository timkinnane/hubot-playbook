Q = require 'q'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/ping.coffee"
observer = require '../utils/observer'
Dialogue = require "../../src/modules/Dialogue"
Scene = require "../../src/modules/Scene"
{EventEmitter} = require 'events'

# helper to attach update callbacks to room messages

describe '#Scene', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom()
    @room.robot.on 'respond', (res) => @res = res # store every latest response

  afterEach ->
    @room.destroy()

  context 'without type', ->

    beforeEach ->
      @scene = new Scene @room.robot
      @debugSpy = sinon.spy @scene.logger, 'debug'
      @room.user.say 'user1', 'hubot ping' # generate response

    afterEach ->
      @debugSpy.restore()

    describe "constructor", ->

      it 'defaults to `user` type', ->
        @scene.type.should.equal 'user'

      it 'attaches the receive middleware to robot', ->
        @room.robot.middleware.receive.stack.length.should.equal 1

      it 'middleware logs that the user is not engaged', ->
        @debugSpy.should.have.been.calledWithMatch /user1/
        @debugSpy.should.have.been.calledWithMatch /not engaged/

    describe '.whoSpeaks', ->

      it 'returns the username on engaged user', ->
        @scene.whoSpeaks @res.message
        .should.equal 'user1'

    describe '.enter', ->

      context 'without arguments', ->

        beforeEach ->
          @dialogue = @scene.enter @res

        it 'saves engaged Dialogue instance with username key', ->
          @scene.engaged['user1'].should.be.instanceof Dialogue

        it 'returns Dialogue instance', ->
          @dialogue.should.be.instanceof Dialogue

      context 'with reply argument', ->

        beforeEach (done) ->
          @dialogue = @scene.enter @res, 'hello'
          observer.next @room.messages, -> done()

        it 'sends the reply to the user', ->
          @room.messages.pop().should.eql [ 'hubot', '@user1 hello' ]

      context 'with timeout options', ->

        beforeEach ->
          @dialogue = @scene.enter @res,
            timeout: 100
            timeoutLine: 'foo'

        it 'passes the options to dialogue config', ->
          @dialogue.config.timeout.should.equal 100
          @dialogue.config.timeoutLine.should.equal 'foo'

      context 'with timout options and reply', ->

        beforeEach (done) ->
          @dialogue = @scene.enter @res, 'hello',
            timeout: 100
            timeoutLine: 'foo'
          observer.next @room.messages, -> done()

        it 'sends the reply to the user', ->
          @room.messages.pop().should.eql [ 'hubot', '@user1 hello' ]

        it 'passes the options to dialogue config', ->
          @dialogue.config.timeout.should.equal 100
          @dialogue.config.timeoutLine.should.equal 'foo'

      context 'dialogue allowed to timeout', ->

        beforeEach (done) ->
          @dialogue = @scene.enter @res, timeout: 10
          @timeoutSpy = sinon.spy @scene, 'exit'
          @timeoutSpy.withArgs @res, 'timed out'
          Q.delay(15).done -> done()

        it 'calls scene exit with response and "timed out"', ->
          @timeoutSpy.should.have.been.calledOnce

      context 'dialogue completed', ->

        beforeEach ->
          @dialogue = @scene.enter @res
          @completeSpy = sinon.spy @scene, 'exit'
          @completeSpy.withArgs @res, 'completed'
          @dialogue.choice /test/, () -> null
          @room.user.say 'user1', 'test'

        it 'calls scene exit with response and "completed"', ->
          @completeSpy.should.have.been.calledOnce

    describe '.exit', ->

      context 'user in dialogue', ->

        beforeEach ->
          @dialogue = @scene.enter @res
          @timeoutSpy = sinon.spy @dialogue, 'clearTimeout'
          @exitStatus = @scene.exit @res, 'testing'

        it 'dialogue should clear timeout', ->
          @timeoutSpy.should.have.been.calledOnce
        #
        # it 'should have removed the dialogue', ->
        #   console.log @scene.engaged
        #   @dialogue.should.not.exist
        #
        # it 'returns true', ->
        #   @exitStatus.should.be.true

      # context 'user not in dialogue', ->
      #
      #   beforeEach (done) ->
      #     @dialogue = @scene.enter @res, timeout: 10
      #     Q.delay(15).done =>
      #       @exitStatus = false # @scene.exit @res, 'testing'
      #       done()
      #
      #   it 'returns false', ->
      #     @exitStatus.should.be.false

  # TODO: and these...
  context 'with room type', ->
    describe '.whoSpeaks', ->
  context 'with userRoom type', ->
    describe '.whoSpeaks', ->

  # TODO: message tests dialogue choices allow matching from
  # - user scene = user in any room
  # - group scene = anyone in room, not other rooms
  # - userRoom scene = user in room, not other rooms
  # - Use examples from hubot-conversation and strato index

# TODO: Add complete test to Dialogue (should fire after last choice handler)
# TODO: Add test that user scene dialogue will only "respond", group will "hear"
# TODO: Matched choices through during scene are saved to array - can be got
