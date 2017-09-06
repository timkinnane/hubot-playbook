sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
co = require 'co'
chai.use require 'sinon-chai'
chai.use require 'chai-subset'
_ = require 'lodash'
pretend = require 'hubot-pretend'

playbook = null

describe 'Playbook - singleton', ->

  beforeEach ->
    playbook = require '../../lib'

  it 'require returns instance', ->
    playbook.constructor.name.should.equal 'Playbook'

  it 'instance contains modules', ->
    playbook.should.containSubset
      Dialogue: require '../../lib/modules/dialogue'
      Scene: require '../../lib/modules/scene'
      Director: require '../../lib/modules/director'
      Transcript: require '../../lib/modules/transcript'
      Outline: require '../../lib/modules/outline'
      improv: require '../../lib/modules/improv'

  it 're-require returns the same instance', ->
    playbook.foo = 'bar'
    playbook = require '../../lib'
    playbook.foo.should.equal 'bar'

  describe '.reset', ->

    it 'returns new instance', ->
      playbook.foo = 'bar'
      playbook = playbook.reset()
      should.not.exist playbook.foo

  describe '.use', ->

    it 'attaches robot', ->
      pretend.start()
      playbook.use pretend.robot
      .should.have.property 'robot', pretend.robot

    it 'inherits robot log', ->
      pretend.start()
      playbook.use pretend.robot
      .should.have.property 'log', pretend.log

  after ->
    pretend.shutdown()

describe 'Playbook', ->

  before ->
    playbook = require '../../lib'

  beforeEach ->
    pretend.start()
    playbook.use pretend.robot

  afterEach ->
    pretend.shutdown()
    playbook = playbook.reset()

  describe 'dialogue', ->

    it 'creates Dialogue instance', ->
      playbook.dialogue pretend.response 'tester', 'test'
      .should.be.instanceof playbook.Dialogue

    it 'stores it in the dialogues array', ->
      dialogue = playbook.dialogue pretend.response 'tester', 'test'
      playbook.dialogues[0].should.eql dialogue

  describe 'scene', ->

    it 'makes a Scene :P', ->
      playbook.scene()
      .should.be.instanceof playbook.Scene

    it 'stores it in the scenes array', ->
      scene = playbook.scene()
      playbook.scenes[0].should.eql scene

  describe '.sceneEnter', ->

    context 'without type or args (other than response)', ->

      it 'makes scene with default user type', ->
        playbook.sceneEnter pretend.response 'tester', 'test', 'testing'
        playbook.scenes[0].should.be.instanceof playbook.Scene

      it 'returns a dialogue', ->
        playbook.sceneEnter pretend.response 'tester', 'test'
        .should.be.instanceof playbook.Dialogue

      it 'enters scene, engaging user (stores against id)', ->
        dialogue = playbook.sceneEnter pretend.response 'tester', 'test'
        playbook.scenes[0].engaged[pretend.users.tester.id].should.eql dialogue

    context 'with type and options args', ->

      it 'used the given room type', ->
        res = pretend.response 'tester', 'test', 'testing'
        playbook.sceneEnter res,
          scope: 'room'
          sendReplies: false
        playbook.scenes[0].config.scope.should.equal 'room'

      it 'passed the scene options to dialogue', ->
        res = pretend.response 'tester', 'test', 'testing'
        dialogue = playbook.sceneEnter res,
          scope: 'room'
          sendReplies: false
        dialogue.config.sendReplies.should.be.false

  describe '.sceneListen', ->

    context 'with scene args', ->

      beforeEach ->
        sinon.spy playbook, 'scene'
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
        sinon.spy playbook, 'scene'
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
      sinon.spy playbook, 'sceneListen'
      playbook.sceneHear /test/, scope: 'room', (res) ->

    it 'calls .sceneListen with hear type and any other args', ->
      args = ['hear', /test/, scope: 'room', sinon.match.func]
      playbook.sceneListen.lastCall
      .should.have.calledWith args...

  describe '.sceneRespond', ->

    beforeEach ->
      sinon.spy playbook, 'sceneListen'
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
      sinon.spy playbook, 'transcript'
      pretend.user('tester').send 'test'
      .then ->
        res = pretend.response 'tester', 'test'
        director = playbook.director()
        scene = playbook.scene()
        dialogue = playbook.dialogue res
        clock = sinon.useFakeTimers()
        config =
          events: ['enter', 'send']
          instanceAtts: 'name'
          responseAtts: null
          messageAtts: null
        playbook.transcribe director, config
        playbook.transcribe scene, config
        playbook.transcribe dialogue, config
        director.process res
        scene.enter res
        dialogue.send 'test'

    it 'creates transcripts for each module', ->
      playbook.transcript.should.have.calledThrice

    it 'records events from given instances in brain', ->
      pretend.robot.brain.get('transcripts').should.eql [
        time: 0
        event: 'deny'
        instance: name: 'director'
      ,
        time: 0
        event: 'enter'
        instance: name: 'scene'
      ,
        time: 0
        event: 'send'
        instance: name: 'dialogue'
        strings: [ 'test' ]
      ]

  describe '.improvise', ->

    it 'returns the improv singleton', ->
      playbook.improvise()
      .should.eql playbook.improv

    context 'with non-improv playbook', ->

      beforeEach ->
        pretend.start()
        playbook = playbook.reset()
        playbook.use pretend.robot, false

      it 'does not parse messages', -> co ->
        res = pretend.response 'tester', 'test'
        yield res.send 'hello ${this.user.name}'
        pretend.messages.pop().should.eql [ 'hubot', 'hello ${this.user.name}' ]

      it 'parses after called', -> co ->
        res = pretend.response 'tester', 'test'
        playbook.improvise()
        yield res.send 'hello ${ this.user.name }'
        pretend.messages.pop().should.eql [ 'hubot', 'hello tester' ]

    context 'using custom data transforms', ->

      it 'parses messages with extended context', -> co ->
        res = pretend.response 'tester', 'test'
        playbook.improv.extend (data) ->
          data.user.name = data.user.name.toUpperCase()
          return data
        yield res.send 'hello ${ this.user.name }'
        pretend.messages.pop().should.eql [ 'hubot', 'hello TESTER' ]

    context 'extended using transcript reocrds', ->

      it 'merge the recorded answers with attribute tags', -> co ->
        dialogue = playbook.sceneEnter res = pretend.response 'tester', 'test'
        transcript = playbook.transcribe dialogue, events: ['match']
        playbook.improv.extend (data) ->
          userId = data.user.id
          userColors = transcript.findKeyMatches 'fav-color', data.user.id, 0
          user: favColor: userColors.pop() if userColors.length
        # ...
        yield dialogue.addPath 'what is your favourite colour?', [
          [ /.*/, 'nice! mine is ${ this.user.favColor } too!' ]
        ], 'fav-color'
        # ...
        yield pretend.user('tester').send 'orange'
        pretend.messages.should.eql [
          [ 'hubot', 'what is your favourite colour?' ],
          [ 'tester', 'orange' ],
          [ 'hubot', 'nice! mine is orange too!' ]
        ]

  describe '.shutdown', ->

    it 'calls .exitAll on scenes', ->
      scene = playbook.scene()
      exit = sinon.spy scene, 'exitAll'
      playbook.shutdown()
      exit.should.have.calledOnce

    it 'calls .end on dialogues', ->
      dialogue = playbook.dialogue pretend.response 'tester', 'test'
      end = sinon.spy dialogue, 'end'
      playbook.shutdown()
      end.should.have.calledOnce

  describe '.reset', ->

    it 'shuts down', ->
      sinon.spy playbook, 'shutdown'
      playbook.reset()
      playbook.shutdown.should.have.calledOnce

    it 'returns re-initialised instance', ->
      playbook = playbook.reset()
      should.not.exist playbook.robot
