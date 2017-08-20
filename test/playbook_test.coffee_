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
      .create()
      should.not.exist playbook.foo

describe 'Playbook', ->

  beforeEach ->
    pretend.startup()
    playbook = require '../../src'
    .create().use pretend.robot
    @tester = pretend.user 'tester', room: 'testing', id: 'user_111'
    @clock = sinon.useFakeTimers()
    @now = _.now()

    _.forIn playbook, (val, key) ->
      sinon.spy playbook, key if _.isFunction val

    @tester.send 'test'
    .then => @res = pretend.responses.incoming[0]

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

    context 'without type or args (other than response)', ->

      beforeEach ->
        @dialogue = playbook.sceneEnter @res

      it 'makes scene with default user type', ->
        playbook.scenes[0].should.be.instanceof playbook.Scene

      it 'returns a dialogue', ->
        @dialogue.should.be.instanceof playbook.Dialogue

      it 'enters scene, engaging user (stores against id)', ->
        playbook.scenes[0].engaged['user_111'].should.eql @dialogue

    context 'with type and options args', ->

      beforeEach ->
        @dialogue = playbook.sceneEnter @res, scope: 'room', sendReplies: false

      it 'used the given room type', ->
        playbook.scenes[0].config.scope.should.equal 'room'

      it 'passed the scene options to dialogue', ->
        @dialogue.config.sendReplies = false

  describe '.sceneListen', ->

    context 'with scene args', ->

      beforeEach ->
        pretend.robot.hear /.*/, (@res) => null # hear all responses
        opts = sendReplies: false, scope: 'room'
        @listen = sinon.spy playbook.Scene.prototype, 'listen'
        @scene = playbook.sceneListen 'hear', /test/, opts, (res) ->

      afterEach ->
        @listen.restore()

      it 'creates Scene instance', ->
        @scene.should.be.instanceof playbook.Scene

      it 'passed args to the scene', ->
        playbook.scene.should.have.calledWith sendReplies: false, scope: 'room'

      it 'calls .listen on the scene with type, regex and callback', ->
        @listen.should.have.calledWith 'hear', /test/, sinon.match.func

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
        @listen.should.have.calledWith 'hear', /test/, sinon.match.func

  describe '.sceneHear', ->

    beforeEach ->
      playbook.sceneHear /test/, scope: 'room', (res) ->

    it 'calls .sceneListen with hear type and any other args', ->
      args = ['hear', /test/, scope: 'room', sinon.match.func]
      playbook.sceneListen.lastCall
      .should.have.calledWith args...

  describe '.sceneRespond', ->

    beforeEach ->
      playbook.sceneRespond /test/, scope: 'room', (res) ->

    it 'calls .sceneListen with respond type and any other args', ->
      args = ['respond', /test/, scope: 'room', sinon.match.func]
      playbook.sceneListen.getCall 0
      .should.have.calledWith args...

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
        strings: [ 'test' ]
      ]

  describe '.improvise', ->

    beforeEach ->
      @improv_A = playbook.improvise()
      @improv_B = playbook.improvise()

    it 'returned an Improv singleton', ->
      @improv_A.should.eql playbook.Improv.get()

    it 'kept the singleton as property', ->
      playbook.improv.should.eql playbook.Improv.get()

    it 'subsequent calls return same instance', ->
      @improv_A.should.eql @improv_B

    context 'messages after called', ->

      beforeEach ->
        @res.send 'hello {{ user.name }}'
        pretend.observer.next()

      it 'parses messages with default context', ->
        pretend.messages.pop().should.eql [ 'testing', 'hubot', 'hello tester' ]

    context 'using custom data transforms', ->

      beforeEach ->
        playbook.improv.extend (data) ->
          data.user.name = data.user.name.toUpperCase()
          return data
        @res.send 'hello {{ user.name }}'
        pretend.observer.next()

      it 'parses messages with extended context', ->
        pretend.messages.pop().should.eql [ 'testing', 'hubot', 'hello TESTER' ]

    context 'extended using transcript reocrds', ->

      beforeEach ->
        @scene = playbook.sceneEnter @res, scope: 'user', 'fav-color'
        @transcript = playbook.transcribe @scene, events: 'match'
        @scene.addPath 'what is your favourite colour?', [
          [ /.*/, 'nice!' ]
        ]
        pretend.observer.next()
        .then =>
          @tester.send 'orange'
        .then =>
          playbook.improv.extend =>
            user: favColor: _.head @transcript.findKeyMatches 'fav-color', 0
        .then =>
          @res.send 'mine is {{ user.favColor }} too!'
          pretend.observer.next()

      it 'merge the recorded answers with attribute tags', ->
        pretend.messages.should.eql [
          [ 'testing', 'tester', 'test' ],
          [ 'testing', 'hubot', 'what is your favourite colour?' ],
          [ 'testing', 'tester', 'orange' ],
          [ 'testing', 'hubot', 'nice!' ],
          [ 'testing', 'hubot', 'mine is orange too!' ]
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
