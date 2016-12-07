Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/noScript.coffee"
Dialogue = require "../../src/modules/Dialogue"
Scene = require "../../src/modules/Scene"
{EventEmitter} = require 'events'

describe '#Scene', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @spy = _.mapObject Scene.prototype, (val, key) ->
      sinon.spy Scene.prototype, key # spy on all the class methods
    @room = helper.createRoom()
    @room.robot.respond /test/, (res) => @res = res # command to get res object

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'with default type (user)', ->

    beforeEach ->
      @scene = new Scene @room.robot
      @debugSpy = sinon.spy @scene.logger, 'debug'
      @room.user.say 'user1', 'hubot testing' # generate res (returns promise)

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

      it 'returns a single users username', ->
        @scene.whoSpeaks @res.message
        .should.equal 'user1'

    describe '.enter', ->

      context 'without arguments', ->

        beforeEach -> @dialogue = @scene.enter @res

        it 'saves engaged Dialogue instance with username key', ->
          @scene.engaged['user1'].should.be.instanceof Dialogue

        it 'returns Dialogue instance', ->
          @dialogue.should.be.instanceof Dialogue
