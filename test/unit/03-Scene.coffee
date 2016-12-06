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
  beforeEach (done) ->
    @room = helper.createRoom()
    @room.robot.respond /testing/, (res) => @res = res
    @spy = _.mapObject Scene.prototype, (val, key) ->
      sinon.spy Scene.prototype, key # spy on all the class methods
    Q.delay(100).done -> done() # let it process the messages and create res

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'created with user scope (solo scene)', ->

    beforeEach ->
      @scene = new Scene @room.robot, 'user'
      @debugSpy = sinon.spy @scene.logger, 'debug'
      @room.user.say 'user1', 'hello'

    it 'attaches the receive middleware to robot', ->
      @room.robot.middleware.receive.stack.length.should.equal 1
      @room.robot.middleware.receive.stack[0].should.equal @scene.middleware()

    it 'called the middleware when receiving', ->
      @spy.middleware.should.have.been.calledOnce

    it 'logs that the username was not engaged', ->
      @debugSpy.should.have.been.calledWithMatch /user1/
      @debugSpy.should.have.been.calledWithMatch /not engaged/

  	# soloScene = new Scene @room.robot, 'user'
  	# groupScene = new Scene @room.robot, 'room'
  	# locationScene = new Scene @room.robot, 'userRoom'
