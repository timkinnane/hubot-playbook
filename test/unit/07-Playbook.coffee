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
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'
Playbook = require '../../src/Playbook'

describe '#Playbook', ->

  beforeEach ->
    @room = helper.createRoom name: 'testing'
    @robot = @room.robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    @robot.on 'respond', (res) => @res = res # store every response sent
    @room.user.say 'tester', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  describe 'constructor', ->

    beforeEach ->
      namespace = Playbook: require "../../src/Playbook"
      @constructor = sinon.spy namespace, 'Playbook'
      @playbook = new namespace.Playbook @robot

    it 'does not throw', ->
      @constructor.should.not.have.threw

    it 'has an empty array of scenes', ->
      @playbook.scenes.should.eql []

    it 'has an empty array of dialogues', ->
      @playbook.dialogues.should.eql []

  describe '.scene', ->

    beforeEach ->
      @playbook = new Playbook @robot
      @scene = @playbook.scene()

    it 'makes a Scene :P', ->
      @scene.should.be.instanceof Scene

    it 'does not throw any errors', ->
      @spy.scene.should.not.have.threw

  describe '.sceneEnter', ->

    context 'with type, without options args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.sceneEnter 'room', @res
        unmute()

      it 'makes a Scene (stored, not returned)', ->
        @playbook.scenes[0].should.be.instanceof Scene

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'returns a dialogue', ->
        @dialogue.should.be.instanceof Dialogue

      it 'enters scene, engaging room', ->
        @playbook.scenes[0].engaged['testing'].should.eql @dialogue

    context 'with type and options args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.sceneEnter 'room', @res, reply: false
        unmute()

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'used the options argument', ->
        @dialogue.config.reply = false

    context 'without type or args (other than response)', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.sceneEnter @res
        unmute()

      it 'makes scene with default user type', ->
        @playbook.scenes[0].should.be.instanceof Scene
        @playbook.scenes[0].type.should.equal 'user'

  describe '.sceneListen', ->

    context 'with scene args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @robot.hear /.*/, (@res) => null # get any response for comparison
        opts = reply: false
        @listenSpy = sinon.spy Scene.prototype, 'listen'
        @scene = @playbook.sceneListen 'hear', /test/, 'room', opts, (res) ->
        unmute()

      afterEach ->
        @listenSpy.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof Scene

      it 'passed args to the scene', ->
        @spy.scene.getCall(0).should.have.calledWith 'room', reply: false

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listenSpy.getCall(0).should.have.calledWith args...

    context 'without scene args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @listenSpy = sinon.spy Scene.prototype, 'listen'
        @scene = @playbook.sceneListen 'hear', /test/, (res) ->
        unmute()

      afterEach ->
        @listenSpy.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof Scene

      it 'passed no args to the scene', ->
        @spy.scene.getCall(0).should.have.calledWith()

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listenSpy.getCall(0).should.have.calledWith args...

  describe '.sceneHear', ->

    beforeEach ->
      unmute = mute()
      @playbook = new Playbook @robot
      @playbook.sceneHear /test/, 'room', (res) ->
      unmute()

    it 'calls .sceneListen with hear type and any other args', ->
      args = ['hear', /test/, 'room', sinon.match.func]
      @spy.sceneListen.getCall(0).should.have.calledWith args...

  describe '.sceneRespond', ->

    beforeEach ->
      unmute = mute()
      @playbook = new Playbook @robot
      @playbook.sceneRespond /test/, 'room', (res) ->
      unmute()

    it 'calls .sceneListen with respond type and any other args', ->
      args = ['respond', /test/, 'room', sinon.match.func]
      @spy.sceneListen.getCall(0).should.have.calledWith args...

  describe '.dialogue', ->

    beforeEach ->
      @playbook = new Playbook @robot
      @dialogue = @playbook.dialogue @res

    it 'creates Dialogue instance', ->
      @dialogue.should.be.instanceof Dialogue

    it 'does not throw any errors', ->
      @spy.dialogue.should.not.have.threw

  describe '.shutdown', ->

    beforeEach ->
      unmute = mute()
      @playbook = new Playbook @robot
      @dialogue = @playbook.dialogue @res
      @scene = @playbook.scene()
      @endSpy = sinon.spy @dialogue, 'end'
      @exitSpy = sinon.spy @scene, 'exitAll'
      @playbook.shutdown()
      unmute()

    it 'calls .exitAll on scenes', ->
      @exitSpy.should.have.calledOnce

    it 'calls .end on dialogues', ->
      @endSpy.should.have.calledOnce
