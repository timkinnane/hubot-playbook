sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

_ = require 'lodash'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
Playbook = require '../../src/Playbook'

describe 'Playbook', ->

  beforeEach ->
    pretend.startup()
    pretend.user('tester').in('testing').send 'test'
    .then => @res = pretend.responses.incoming[0]

    _.forIn Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key if _.isFunction val

  afterEach ->
    pretend.shutdown()

    _.forIn Playbook.prototype, (val, key) ->
      Playbook.prototype[key].restore() if _.isFunction val

  describe 'constructor', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot

    it 'has an empty array of dialogues', ->
      @playbook.dialogues.should.eql []

    it 'has an empty array of scenes', ->
      @playbook.scenes.should.eql []

    it 'has an empty array of directors', ->
      @playbook.dialogues.should.eql []

  describe '.director', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @director = @playbook.director()

    it 'creates and returns director', ->
      @director.should.be.instanceof @playbook.Director

    it 'stores it in the directors array', ->
      @playbook.directors[0].should.eql @director

  describe '.scene', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @scene = @playbook.scene()

    it 'makes a Scene :P', ->
      @scene.should.be.instanceof @playbook.Scene

    it 'stores it in the scenes array', ->
      @playbook.scenes[0].should.eql @scene

  describe '.sceneEnter', ->

    context 'with type, without options args', ->

      beforeEach ->
        @playbook = new Playbook pretend.robot
        @dialogue = @playbook.sceneEnter 'room', @res

      it 'makes a Scene (stored, not returned)', ->
        @playbook.scenes[0].should.be.instanceof @playbook.Scene

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'returns a dialogue', ->
        @dialogue.should.be.instanceof @playbook.Dialogue

      it 'enters scene, engaging room', ->
        @playbook.scenes[0].engaged['testing'].should.eql @dialogue

    context 'with type and options args', ->

      beforeEach ->
        @playbook = new Playbook pretend.robot
        @dialogue = @playbook.sceneEnter 'room', @res, reply: false

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'used the options argument', ->
        @dialogue.config.sendReplies = false

    context 'without type or args (other than response)', ->

      beforeEach ->
        @playbook = new Playbook pretend.robot
        @dialogue = @playbook.sceneEnter @res

      it 'makes scene with default user type', ->
        @playbook.scenes[0].should.be.instanceof @playbook.Scene
        @playbook.scenes[0].type.should.equal 'user'

  describe '.sceneListen', ->

    context 'with scene args', ->

      beforeEach ->
        @playbook = new Playbook pretend.robot
        pretend.robot.hear /.*/, (@res) => null # hear all responses
        opts = sendReplies: false
        @listen = sinon.spy @playbook.Scene.prototype, 'listen'
        @scene = @playbook.sceneListen 'hear', /test/, 'room', opts, (res) ->

      afterEach ->
        @listen.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof @playbook.Scene

      it 'passed args to the scene', ->
        @playbook.scene.should.have.calledWith 'room', sendReplies: false

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listen.getCall(0).should.have.calledWith args...

    context 'without scene args', ->

      beforeEach ->
        @playbook = new Playbook pretend.robot
        @listen = sinon.spy @playbook.Scene.prototype, 'listen'
        @scene = @playbook.sceneListen 'hear', /test/, (res) ->

      afterEach ->
        @listen.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof @playbook.Scene

      it 'passed no args to the scene', ->
        @playbook.scene.getCall(0).should.have.calledWith()

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listen.getCall(0).should.have.calledWith args...

  describe '.sceneHear', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @playbook.sceneHear /test/, 'room', (res) ->

    it 'calls .sceneListen with hear type and any other args', ->
      args = ['hear', /test/, 'room', sinon.match.func]
      @playbook.sceneListen.getCall(0).should.have.calledWith args...

  describe '.sceneRespond', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @playbook.sceneRespond /test/, 'room', (res) ->

    it 'calls .sceneListen with respond type and any other args', ->
      args = ['respond', /test/, 'room', sinon.match.func]
      @playbook.sceneListen.getCall(0).should.have.calledWith args...

  describe '.dialogue', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @dialogue = @playbook.dialogue @res

    it 'creates Dialogue instance', ->
      @dialogue.should.be.instanceof @playbook.Dialogue

    it 'does not throw any errors', ->
      @playbook.dialogue.should.not.have.threw

  describe '.shutdown', ->

    beforeEach ->
      @playbook = new Playbook pretend.robot
      @dialogue = @playbook.dialogue @res
      @scene = @playbook.scene()
      @end = sinon.spy @dialogue, 'end'
      @exit = sinon.spy @scene, 'exitAll'
      @playbook.shutdown()

    it 'calls .exitAll on scenes', ->
      @exit.should.have.calledOnce

    it 'calls .end on dialogues', ->
      @end.should.have.calledOnce
