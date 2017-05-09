sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'

_ = require 'lodash'
co = require 'co'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Transcript, Director, Scene, Dialogue, Base} = require '../../src/modules'

describe 'Transcript', ->

  beforeEach ->
    pretend.startup()
    @tester = pretend.user 'tester', room: 'testing'
    @clock = sinon.useFakeTimers()
    @now = _.now()

    _.forIn Transcript.prototype, (val, key) ->
      sinon.spy Transcript.prototype, key if _.isFunction val

    # generate first response for mock events
    @tester.send('test').then => @res = pretend.responses.incoming[0]

  afterEach ->
    pretend.shutdown()
    @clock.restore()

    _.forIn Transcript.prototype, (val, key) ->
      Transcript.prototype[key].restore() if _.isFunction val

  describe 'constructor', ->

    context 'with saving enabled (default)', ->

      beforeEach ->
        pretend.robot.brain.set 'transcripts', [ time: @now, event: 'test' ]
        @transcript = new Transcript pretend.robot

      it 'uses brain for record keeping', ->
        @transcript.records.should.eql [ time: @now, event: 'test' ]

    context 'with saving disabled', ->

      beforeEach ->
        pretend.robot.brain.set 'transcripts', [ time: @now, event: 'test' ]
        @transcript = new Transcript pretend.robot, save: false

      it 'keeps records in a new empty array', ->
        @transcript.records.should.eql []

  describe '.recordEvent', ->

    context 'emitted from Hubot/brain', ->

      beforeEach ->
        @transcript = new Transcript pretend.robot, save: false
        pretend.robot.brain.once 'mockEvent', (args...) =>
          @transcript.recordEvent 'mockEvent', args...
        pretend.robot.brain.emit 'mockEvent', test: 'data'

      it 'records event "other" data', ->
        @transcript.records.should.eql [
          time: @now
          event: 'mockEvent'
          other: [ test: 'data' ]
        ]

    context 'emitted from Playbook module', ->

      beforeEach ->
        class Module extends Base
          constructor: (opts) -> super 'module', pretend.robot, opts

        @transcript = new Transcript pretend.robot, save: false
        @module = new Module key: 'foo'
        @module.on 'mockEvent', (args...) =>
          @transcript.recordEvent 'mockEvent', args...

      context 'with default config', ->

        beforeEach (done) ->
          @record = record = sinon.spy()
          @transcript.on 'record', @record
          @transcript.on 'record', -> done()
          @module.emit 'mockEvent', @res

        it 'records default instance attributes', ->
          @transcript.records[0].should.containSubset instance:
            name: @module.name
            config: key: @module.config.key
            id: @module.id

        it 'records default response attributes', ->
          @transcript.records[0].should.containSubset response:
            match: @res.match

        it 'records default message attributes', ->
          @transcript.records[0].should.containSubset message:
            user:
              id: @res.message.user.id
              name: @res.message.user.name
            room: @res.message.room
            text: @res.message.text

        it 'emits new record once created', ->
          @record.should.have.calledWith @transcript, @transcript.records.pop()

      context 'with transcript key', ->

        beforeEach ->
          @transcript.config.key = 'test-key'
          @module.emit 'mockEvent', @res

        it 'records event with key property', ->
          @transcript.records[0].should.have.property 'key', 'test-key'

      context 'with custom instance atts', ->

        beforeEach ->
          @transcript.config.instanceAtts = ['name', 'config.scope']
          @module.config.scope = 'whitelist' # act like a director for this one
          @module.emit 'mockEvent', @res

        it 'records custom instance attributes', ->
          @transcript.records[0].should.containSubset instance:
            name: @module.name
            config: scope: @module.config.scope

      context 'with custom response atts', ->

        beforeEach ->
          @transcript.config.responseAtts = ['message.room']
          @module.emit 'mockEvent', @res

        it 'records custom response attributes', ->
          @transcript.records[0].should.containSubset response:
            message: room: 'testing'

      context 'with custom message atts', ->

        beforeEach ->
          @transcript.config.messageAtts = ['room']
          @module.emit 'mockEvent', @res

        it 'records custom message attributes', ->
          @transcript.records[0].should.containSubset message:
            room: 'testing'

      context 'without res argument', ->

        beforeEach ->
          @module.emit 'mockEvent'

        it 'records event without response or other attributes', ->
          @transcript.records.should.eql [
            time: @now
            event: 'mockEvent'
            instance:
              name: @module.name
              config: key: @module.config.key
              id: @module.id
          ]

      context 'with invalid custom response atts', ->

        beforeEach ->
          @transcript.config.responseAtts = ['foo', 'bar']
          @module.emit 'mockEvent'

        it 'records event without response attributes', ->
          @transcript.records.should.eql [
            time: @now
            event: 'mockEvent'
            instance:
              name: @module.name
              config: key: @module.config.key
              id: @module.id
          ]

        it 'does not throw', ->
          @transcript.recordEvent.should.not.have.threw

  describe '.recordAll', ->

    context 'with default event set', ->

      beforeEach ->
        @transcript = new Transcript pretend.robot, save: false
        @transcript.recordAll()
        pretend.robot.emit 'match'
        pretend.robot.emit 'mismatch'
        pretend.robot.emit 'foo'
        pretend.robot.emit 'catch'
        pretend.robot.emit 'send'

      it 'records default events only', ->
        @transcript.recordEvent.args.should.eql [
          ['match'], ['mismatch'], ['catch'], ['send']
        ]

    context 'with custom event set', ->

      beforeEach ->
        @transcript = new Transcript pretend.robot,
          save: false
          events: ['foo', 'bar']
        @transcript.recordAll()
        pretend.robot.emit 'match'
        pretend.robot.emit 'foo'
        pretend.robot.emit 'mismatch'
        pretend.robot.emit 'bar'

      it 'records custom events only', ->
        @transcript.recordEvent.args.should.eql [
          ['foo'], ['bar']
        ]

  describe '.recordDialogue', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @dialogue = new Dialogue @res

    context 'with default event set', ->

      beforeEach (done) ->
        pretend.robot.events.removeAllListeners()
        @transcript.recordDialogue @dialogue
        @dialogue.on 'match', -> done()
        @dialogue.emit 'match'

      it 'attached listener for default events from dialogue', ->
        _.keys pretend.robot.events._events
        .should.eql @transcript.config.events
        # TODO: could use events.eventNames() when EventEmitter in hubot updated

      it 'calls the listener when event emmited from dialogue', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue

    context 'with custom event set', ->

      beforeEach (done) ->
        pretend.robot.events.removeAllListeners()
        @transcript.config.events = ['match', 'mismatch']
        @transcript.recordDialogue @dialogue
        @dialogue.emit 'send'
        @dialogue.on 'match', -> done()
        @dialogue.emit 'match'

      it 'attached listener for default events from dialogue', ->
        _.keys pretend.robot.events._events
        .should.eql ['match', 'mismatch']

      it 'calls the listener when event emmited from dialogue', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue

      it 'does not call with any unconfigured events', ->
        @transcript.recordEvent.should.not.have.calledWith 'send', @dialogue

  describe '.recordScene', ->

    beforeEach (done) ->
      pretend.robot.events.removeAllListeners()
      @transcript = new Transcript pretend.robot,
        save: false
        events: ['match']
      @scene = new Scene pretend.robot
      @transcript.recordScene @scene
      @dialogue = @scene.enter @res
      @dialogue.addBranch /.*/, -> done()
      @dialogue.receive @res

    it 'attached listener for scene and dialogue events', ->
      _.keys pretend.robot.events._events
      .should.containSubset ['enter', 'exit', 'match']
      # subset checked because scene enter adds its own listeners

    it 'records events emitted by scene and its dialogues', ->
      @transcript.recordEvent.args.should.eql [
        [ 'enter', @scene, @res ]
        [ 'match', @dialogue, @res ]
      ]

  describe '.recordDirector', ->

    beforeEach (done) ->
      pretend.robot.events.removeAllListeners()
      @transcript = new Transcript pretend.robot, save: false
      @director = new Director pretend.robot, type: 'blacklist'
      @transcript.recordDirector @director
      @director.on 'allow', -> done()
      @director.names = ['tester']
      @director.process @res
      @director.config.type = 'whitelist'
      @director.process @res

    it 'attached listeners for director events', ->
      _.keys pretend.robot.events._events
      .should.eql ['allow', 'deny']

    it 'records events emitted by director', ->
      @transcript.recordEvent.args.should.eql [
        [ 'deny', @director, @res ]
        [ 'allow', @director, @res ]
      ]

  describe '.findRecords', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @transcript.records = [
        time: 0
        event: 'match'
        instance: config: key: 'time'
        message: user: name: 'jon', text: 'now'
      ,
        time: 0
        event: 'match'
        instance: config: key: 'direction'
        message: user: name: 'jon', text: 'left'
      ,
        time: 0
        event: 'match'
        instance: config: key: 'time'
        message: user: name: 'luc', text: 'later'
      ,
        time: 0
        event: 'match'
        instance: config: key: 'direction'
        message: user: name: 'luc', text: 'right'
      ]

    context 'with record subset matcher', ->

      beforeEach ->
        @transcript.findRecords message: user: name: 'jon'

      it 'returns records matching given attributes', ->
        @transcript.findRecords.returnValues[0].should.eql [
          time: 0
          event: 'match'
          instance: config: key: 'time'
          message: user: name: 'jon', text: 'now'
        ,
          time: 0
          event: 'match'
          instance: config: key: 'direction'
          message: user: name: 'jon', text: 'left'
        ]

    context 'with record subset and path matcher', ->

      beforeEach ->
        @transcript.findRecords message: user: name: 'jon', 'message.user.text'

      it 'returns only the values at path', ->
        @transcript.findRecords.returnValues[0].should.eql [ 'now', 'left' ]
