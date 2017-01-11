Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../scripts/ping.coffee"
Observer = require '../utils/observer'

Dialogue = require "../../src/modules/Dialogue"
Scene = require "../../src/modules/Scene"
{EventEmitter} = require 'events'

describe '#Scene', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'
    @observer = new Observer @room.messages
    @room.robot.on 'respond', (res) => @res = res # store every response sent
    @room.robot.on 'receive', (res) => @rec = res # store every message received
    @spy = _.mapObject Scene.prototype, (val, key) ->
      sinon.spy Scene.prototype, key # spy on all the class methods
    @room.user.say 'tester', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'without type', ->

    beforeEach ->
      namespace = Scene: require "../../src/modules/Scene"
      @constructor = sinon.spy namespace, 'Scene'
      @scene = new namespace.Scene @room.robot

    describe "constructor", ->

      it 'has no errors when not given type', ->
        @constructor.should.not.have.threw

      it 'defaults to `user` type', ->
        @scene.type.should.equal 'user'

      it 'attaches the receive middleware to robot', ->
        @room.robot.middleware.receive.stack.length.should.equal 2
        # length is 2 because of test helper middleware added by ping.coffee

    describe '.whoSpeaks', ->

      beforeEach ->
        @result = @scene.whoSpeaks @res

      it 'returns the username of engaged user', ->
        @result.should.equal 'tester'

    describe '.enter', ->

      context 'without options', ->

        beforeEach ->
          unmute = mute()
          @dialogue = @scene.enter @res
          unmute()

        it 'saves engaged Dialogue instance with username key', ->
          @scene.engaged['tester'].should.be.instanceof Dialogue

        it 'returns Dialogue instance', ->
          @dialogue.should.be.instanceof Dialogue

      context 'with reply option: true', ->

        beforeEach (done) ->
          unmute = mute()
          @observer.next().then -> done()
          @dialogue = @scene.enter @res, reply: true
          @dialogue.send 'hello'
          unmute()

        it 'sends with prefix replying to the user', ->
          @room.messages.pop().should.eql [ 'hubot', '@tester hello' ]

      context 'with reply option: false', ->

        beforeEach (done) ->
          unmute = mute()
          @observer.next().then -> done()
          @dialogue = @scene.enter @res, reply: false
          @dialogue.send 'hello'
          unmute()

        it 'sends without prefix', ->
          @room.messages.pop().should.eql [ 'hubot', 'hello' ]

      context 'with timeout options', ->

        beforeEach ->
          unmute = mute()
          @dialogue = @scene.enter @res,
            timeout: 100
            timeoutLine: 'foo'
          unmute()

        it 'passes the options to dialogue config', ->
          @dialogue.config.timeout.should.equal 100
          @dialogue.config.timeoutLine.should.equal 'foo'

      context 'dialogue allowed to timeout after branch added', ->

        beforeEach (done) ->
          unmute = mute()
          @dialogue = @scene.enter @res,
            timeout: 10,
            timeoutLine: null
          @dialogue.on 'end', ->
            unmute()
            done()
          @dialogue.branch /.*/, ''

        it 'calls .exit twice, on "timeout" then "incomplete"', ->
          @spy.exit.should.have.calledWith @res, 'timeout'
          @spy.exit.should.have.calledWith @res, 'incomplete'

      context 'dialogue completed (by message matching branch)', ->

        beforeEach (done) ->
          unmute = mute()
          @dialogue = @scene.enter @res
          @dialogue.on 'end', ->
            unmute()
            done()
          @dialogue.branch /.*/, '' # match anything
          @room.user.say 'tester', 'test'
          return # hack to avoid returning promise

        it 'calls .exit once with "complete"', ->
          @spy.exit.should.have.calledWith @res, 'complete'

    describe '.exit', ->

      context 'with user in scene, called manually', ->

        beforeEach ->
          unmute = mute()
          @dialogue = @scene.enter @res, timeout: 10
          @dialogue.branch /.*/, '' # starts timeout
          @timeout = sinon.spy()
          @dialogue.onTimeout => @timeout()
          @result = @scene.exit @res, 'testing'
          Q.delay 15
          .then ->
            unmute()

        it 'does not call onTimeout on dialogue', ->
          @timeout.should.not.have.called

        it 'removes the dialogue instance from engaged array', ->
          should.not.exist @scene.engaged['tester']

        it 'returns true', ->
          @result.should.be.true

      context 'with user in scene, called from events', ->

        beforeEach (done) ->
          unmute = mute()
          @dialogue = @scene.enter @res, timeout: 10
          @dialogue.on 'end', ->
            unmute()
            done()
          @dialogue.branch /.*/, '' # starts timeout

        it 'gets called twice (on timeout and end)', ->
          @spy.exit.should.have.calledTwice

        it 'returns true the first time', ->
          @spy.exit.getCall(0).should.have.returned true

        it 'returns false the second time (because already disengaged)', ->
          @spy.exit.getCall(1).should.have.returned false

      context 'user not in scene, called manually', ->

        beforeEach ->
          @result = @scene.exit @res, 'testing'

        it 'returns false', ->
          @result.should.be.false

    describe '.dialogue', ->

      context 'with user in scene', ->

        beforeEach ->
          unmute = mute()
          @dialogue = @scene.enter @res
          @result = @scene.dialogue 'tester'
          unmute()

        it 'returns the matching dialogue', ->
          @result.should.eql @dialogue

      context 'no user in scene', ->

        beforeEach ->
          @result = @scene.dialogue 'tester'

        it 'returns null', ->
          should.equal @result, null

    describe '.inDialogue', ->

      context 'with user in scene (engaged)', ->

        beforeEach ->
          unmute = mute()
          @scene.enter @res
          @userEngaged = @scene.inDialogue 'tester'
          @roomEngaged = @scene.inDialogue 'testing'
          unmute()

        it 'returns true with username', ->
          @userEngaged.should.be.true

        it 'returns false with room name', ->
          @roomEngaged.should.be.false

      context 'no user in scene', ->

        beforeEach ->
          @userEngaged = @scene.inDialogue 'tester'

        it 'returns false', ->
          @userEngaged.should.be.false

  context 'with "room" type', ->

    beforeEach ->
      unmute = mute()
      @scene = new Scene @room.robot, 'room'
      @scene.enter @res
      unmute()

    describe '.whoSpeaks', ->

      beforeEach ->
        @result = @scene.whoSpeaks @res

      it 'returns the room ID', ->
        @result.should.equal 'testing'

    describe '.inDialogue', ->

      beforeEach ->
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'

      it 'returns true with roomname', ->
        @roomEngaged.should.be.true

      it 'returns false with username', ->
        @userEngaged.should.be.false

  context 'with "userRoom" type', ->

    beforeEach ->
      unmute = mute()
      @scene = new Scene @room.robot, 'userRoom'
      @scene.enter @res
      unmute()

    describe '.whoSpeaks', ->

      beforeEach ->
        @result = @scene.whoSpeaks @res

      it 'returns the concatenated username and room ID', ->
        @result.should.equal 'tester_testing'

    describe '.inDialogue', ->

      beforeEach ->
        @roomEngaged = @scene.inDialogue 'testing'
        @userEngaged = @scene.inDialogue 'tester'
        @userRoomEngaged = @scene.inDialogue 'tester_testing'

      it 'returns true with ${username}_${roomID}', ->
        @userRoomEngaged.should.be.true

      it 'returns false with roomname', ->
        @roomEngaged.should.be.false

      it 'returns false with username', ->
        @userEngaged.should.be.false

  # TODO: message tests dialogue choices allow matching from
  # - user scene = user in any room
  # - room scene = anyone in room, not other rooms
  # - userRoom scene = user in room, not other rooms
  # - Use examples from hubot-conversation and strato index
  # - engage user in room, should ignore other users
  # - engage two separate users in room, run parallel dialogues without conflict

# TODO: Add test that user scene dialogue will only "respond", group will "hear"
# TODO: Matched choices through during scene are saved to array - can be got
