Q = require 'q'
_ = require 'underscore'
require('underscore-observe')(_) # extends underscore
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/ping.coffee"
Dialogue = require "../../src/modules/Dialogue"
Scene = require "../../src/modules/Scene"
{EventEmitter} = require 'events'

# helper to attach update callbacks to room messages

# look for any new message
observeNext = (messages, cb) ->
  start = messages.length
  _.observe messages, 'create', (created) ->
    if messages.length > start
      _.unobserve()
      cb created

# look for a specific message
observeWhen = (messages, message, cb) ->
  _.observe messages, 'create', (created)->
    if message is created
      _.unobserve()
      cb created

# look at every message
observe = (messages, cb) -> _.observe messages, 'create', -> cb() # every time
unobserve = -> _.unobserve() # alias for consistent syntax

describe '#Scene', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom()
    @room.robot.on 'respond', (res) => @res = res # store every latest response

  afterEach ->
    @room.destroy()
    delete @observer

  context 'without type', ->

    beforeEach ->
      @scene = new Scene @room.robot
      @debugSpy = sinon.spy @scene.logger, 'debug'
      @room.user.say 'user1', 'hubot ping' # generate response

    afterEach ->
      @debugSpy.restore()
      delete @scene

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

        beforeEach -> @dialogue = @scene.enter @res

        it 'saves engaged Dialogue instance with username key', ->
          @scene.engaged['user1'].should.be.instanceof Dialogue

        it 'returns Dialogue instance', ->
          @dialogue.should.be.instanceof Dialogue

      context 'with reply argument', ->

        beforeEach (done) ->
          @dialogue = @scene.enter @res, 'hello'
          observeNext @room.messages, -> done()

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
          observeNext @room.messages, -> done()

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
          Q.delay(10).done -> done()

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

    # TODO: these...
    describe '.exit', ->
      # @dialogue.countdown._called.should.be.true
      # @dialogue.should.not.exist
      # returns true for user in dialogue
      # returns false for user not in dialogue

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
