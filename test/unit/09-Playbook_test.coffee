sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

_ = require 'lodash'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
playbook = null

describe 'Playbook - singleton', ->

  context 'require as property', ->

    it 'returns instance', ->
      {playbook} = require '../../src'
      playbook.should.have.property 'transcripts'

  context 'require with get method', ->

    it 'returns instance', ->
      playbook = require('../../src')
      .get()
      playbook.should.have.property 'transcripts'

  context 'require and use robot in one', ->

    it 'returns instance initialised with bot', ->
      pretend.startup()
      playbook = require('../../src')
      .use pretend.robot
      playbook.should.have.property 'log'

  context 're-require instance', ->

    it 'returns the same instance', ->
      {playbook} = require '../../src'
      playbook.foo = 'bar'
      {playbook} = require '../../src'
      playbook.foo.should.equal 'bar'

  context 'require a recreated instance', ->

    it 'creates a new instance', ->
      playbook = require '../../src'
      .get()
      playbook.foo = 'bar'
      playbook = require '../../src'
      .recreate()
      should.not.exist playbook.foo

describe 'Playbook', ->

  beforeEach ->
    pretend.startup()
    playbook = require '../../src'
    .recreate().use pretend.robot
    @clock = sinon.useFakeTimers()
    @now = _.now()

    pretend.user('tester').in('testing').send 'test'
    .then => @res = pretend.responses.incoming[0]

    _.forIn playbook, (val, key) ->
      sinon.spy playbook, key if _.isFunction val

  afterEach ->
    pretend.shutdown()
    playbook.shutdown()

  describe '.use', ->

    context 'first time with robot', ->

      it 'attaches playbook to bot', ->
        playbook.use pretend.robot
        pretend.robot.playbook.should.eql playbook

    context 'used again with robot', ->

      it 'returns the robots existing Playbook', ->
        playbook.use pretend.robot
        pretend.robot.playbook.foo = 'bar'
        playbook.use pretend.robot
        pretend.robot.playbook.foo.should.equal 'bar'

  describe '.dialogue', ->

    beforeEach ->
      @dialogue = playbook.dialogue @res

    it 'creates Dialogue instance', ->
      @dialogue.should.be.instanceof playbook.Dialogue

    it 'does not throw any errors', ->
      playbook.dialogue.should.not.have.threw

  describe '.scene', ->

    beforeEach ->
      @scene = playbook.scene()

    it 'makes a Scene :P', ->
      @scene.should.be.instanceof playbook.Scene

    it 'stores it in the scenes array', ->
      playbook.scenes[0].should.eql @scene

  describe '.sceneEnter', ->

    context 'with type, without options args', ->

      beforeEach ->
        @dialogue = playbook.sceneEnter 'room', @res

      it 'makes a Scene (stored, not returned)', ->
        playbook.scenes[0].should.be.instanceof playbook.Scene

      it 'used the given room type', ->
        playbook.scenes[0].type.should.equal 'room'

      it 'returns a dialogue', ->
        @dialogue.should.be.instanceof playbook.Dialogue

      it 'enters scene, engaging room', ->
        playbook.scenes[0].engaged['testing'].should.eql @dialogue

    context 'with type and options args', ->

      beforeEach ->
        @dialogue = playbook.sceneEnter 'room', @res, reply: false

      it 'used the given room type', ->
        playbook.scenes[0].type.should.equal 'room'

      it 'used the options argument', ->
        @dialogue.config.sendReplies = false

    context 'without type or args (other than response)', ->

      beforeEach ->
        @dialogue = playbook.sceneEnter @res

      it 'makes scene with default user type', ->
        playbook.scenes[0].should.be.instanceof playbook.Scene
        playbook.scenes[0].type.should.equal 'user'

  describe '.sceneListen', ->

    context 'with scene args', ->

      beforeEach ->
        pretend.robot.hear /.*/, (@res) => null # hear all responses
        opts = sendReplies: false
        @listen = sinon.spy playbook.Scene.prototype, 'listen'
        @scene = playbook.sceneListen 'hear', /test/, 'room', opts, (res) ->

      afterEach ->
        @listen.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof playbook.Scene

      it 'passed args to the scene', ->
        playbook.scene.should.have.calledWith 'room', sendReplies: false

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listen.getCall(0).should.have.calledWith args...

    context 'without scene args', ->

      beforeEach ->
        @listen = sinon.spy playbook.Scene.prototype, 'listen'
        @scene = playbook.sceneListen 'hear', /test/, (res) ->

      afterEach ->
        @listen.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof playbook.Scene

      it 'passed no args to the scene', ->
        playbook.scene.getCall(0).should.have.calledWith()

      it 'calls .listen on the scene with type, regex and callback', ->
        args = ['hear', /test/, sinon.match.func]
        @listen.getCall(0).should.have.calledWith args...

  describe '.sceneHear', ->

    beforeEach ->
      playbook.sceneHear /test/, 'room', (res) ->

    it 'calls .sceneListen with hear type and any other args', ->
      args = ['hear', /test/, 'room', sinon.match.func]
      playbook.sceneListen.getCall(0).should.have.calledWith args...

  describe '.sceneRespond', ->

    beforeEach ->
      playbook.sceneRespond /test/, 'room', (res) ->

    it 'calls .sceneListen with respond type and any other args', ->
      args = ['respond', /test/, 'room', sinon.match.func]
      playbook.sceneListen.getCall(0).should.have.calledWith args...

  describe '.director', ->

    beforeEach ->
      @director = playbook.director()

    it 'creates and returns director', ->
      @director.should.be.instanceof playbook.Director

    it 'stores it in the directors array', ->
      playbook.directors[0].should.eql @director

  describe '.transcript', ->

    beforeEach ->
      @transcript = playbook.transcript()

    it 'creates and returns transcript', ->
      @transcript.should.be.instanceof playbook.Transcript

    it 'stores it in the transcripts array', ->
      playbook.transcripts[0].should.eql @transcript

  describe '.transcribe', ->

    beforeEach ->
      @director = playbook.director()
      @scene = playbook.scene()
      @dialogue = playbook.dialogue @res
      config =
        instanceAtts: 'name'
        responseAtts: null
        messageAtts: null
      playbook.transcribe @director, config
      playbook.transcribe @scene, config
      playbook.transcribe @dialogue, config

      @director.process @res
      @scene.enter @res
      @dialogue.send 'test'

    it 'creates transcripts', ->
      playbook.transcript.should.have.calledThrice

    it 'records events from given instances in brain', ->
      pretend.robot.brain.get('transcripts').should.eql [
        time: @now
        event: 'deny'
        instance: name: 'director'
      ,
        time: @now
        event: 'enter'
        instance: name: 'scene'
      ,
        time: @now
        event: 'send'
        instance: name: 'dialogue'
      ]

  describe '.shutdown', ->

    beforeEach ->
      @dialogue = playbook.dialogue @res
      @scene = playbook.scene()
      @end = sinon.spy @dialogue, 'end'
      @exit = sinon.spy @scene, 'exitAll'
      playbook.shutdown()

    it 'calls .exitAll on scenes', ->
      @exit.should.have.calledOnce

    it 'calls .end on dialogues', ->
      @end.should.have.calledOnce

  describe '.reset', ->

    beforeEach ->
      playbook.foo = 'bar'
      playbook.reset()

    it 'shuts down', ->
      playbook.shutdown.should.have.calledOnce

    it 're-initialises', ->
      playbook.init.should.have.calledOnce

    it 'retains any custom properties', ->
      playbook.foo.should.equal 'bar'
