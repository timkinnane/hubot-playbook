sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'

_ = require 'lodash'
pretend = require 'hubot-pretend'
Transcript = require '../../lib/modules/transcript'
Director = require '../../lib/modules/director'
Scene = require '../../lib/modules/scene'
Dialogue = require '../../lib/modules/dialogue'
Base = require '../../lib/modules/base'
Module = require '../../lib/utils/module'

# helper clears existing listeners to check specific listeners are added
removeListeners = (robot) -> robot.events.removeAllListeners.apply robot

describe 'Transcript', ->

  beforeEach ->
    pretend.start()
    @tester = pretend.user 'tester', room: 'testing'
    @clock = sinon.useFakeTimers()
    @now = _.now()

    Object.getOwnPropertyNames(Transcript.prototype).map (key) ->
      sinon.spy Transcript.prototype, key

    # generate first response for mock events
    yield @tester.send('test')
    @res = pretend.responses.incoming[0]

  afterEach ->
    pretend.shutdown()
    @clock.restore()

    Object.getOwnPropertyNames(Transcript.prototype).map (key) ->
      Transcript.prototype[key].restore()

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
        @transcript = new Transcript pretend.robot, save: false
        @module = new Module pretend.robot, 'foo'
        @module.on 'mockEvent', (args...) =>
          @transcript.recordEvent 'mockEvent', args...

      context 'with default config', ->

        it 'records default instance attributes', (done) ->
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset instance:
              name: @module.name
              key: @module.key
              id: @module.id
            done()
          @module.emit 'mockEvent', @res

        it 'records default response attributes', (done) ->
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset response:
              match: @res.match
            done()
          @module.emit 'mockEvent', @res

        it 'records default message attributes', (done) ->
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset message:
              user:
                id: @res.message.user.id
                name: @res.message.user.name
              room: @res.message.room
              text: @res.message.text
            done()
          @module.emit 'mockEvent', @res

      context 'with transcript key', ->

        beforeEach ->
          @transcript.key = 'test-key'
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
          @transcript.config.messageAtts = 'room'
          @module.emit 'mockEvent', @res

        it 'records custom message attributes', ->
          @transcript.records[0].should.containSubset message:
            room: 'testing'

      context 'on event without res argument', ->

        beforeEach ->
          @module.emit 'mockEvent'

        it 'records event without response or other attributes', ->
          @transcript.records.should.eql [
            time: @now
            event: 'mockEvent'
            instance:
              name: @module.name
              key: @module.key
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
              key: @module.key
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
        removeListeners pretend.robot
        @transcript.recordDialogue @dialogue
        @dialogue.on 'match', -> done()
        @dialogue.emit 'match'

      it 'attached listener for default events from dialogue', ->
        _.keys pretend.robot._events
        .should.eql @transcript.config.events

      it 'calls the listener when event emmited from dialogue', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue

    context 'with custom event set', ->

      beforeEach (done) ->
        removeListeners pretend.robot
        @transcript.config.events = ['match', 'mismatch']
        @transcript.recordDialogue @dialogue
        @dialogue.emit 'send'
        @dialogue.on 'match', -> done()
        @dialogue.emit 'match'

      it 'attached listener for default events from dialogue', ->
        _.keys pretend.robot._events
        .should.eql ['match', 'mismatch']

      it 'calls the listener when event emmited from dialogue', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue

      it 'does not call with any unconfigured events', ->
        @transcript.recordEvent.should.not.have.calledWith 'send', @dialogue

  describe '.recordScene', ->

    beforeEach (done) ->
      removeListeners pretend.robot
      @transcript = new Transcript pretend.robot,
        save: false
        events: ['match']
      @scene = new Scene pretend.robot
      @transcript.recordScene @scene
      @dialogue = @scene.enter @res
      @dialogue.addBranch /.*/, -> done()
      @dialogue.receive @res

    it 'attached listener for scene and dialogue events', ->
      _.keys pretend.robot._events
      .should.containSubset ['enter', 'exit', 'match']
      # subset checked because scene enter adds its own listeners

    it 'records events emitted by scene and its dialogues', ->
      @transcript.recordEvent.args.should.eql [
        [ 'enter', @scene, @res ]
        [ 'match', @dialogue, @res ]
      ]

  describe '.recordDirector', ->

    beforeEach (done) ->
      removeListeners pretend.robot
      @transcript = new Transcript pretend.robot, save: false
      @director = new Director pretend.robot, type: 'blacklist'
      @transcript.recordDirector @director
      @director.on 'allow', -> done()
      @director.names = ['tester']
      @director.process @res
      @director.config.type = 'whitelist'
      @director.process @res

    it 'attached listeners for director events', ->
      _.keys pretend.robot._events
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
        instance: key: 'time'
        message:
          user: name: 'jon'
          text: 'now'
      ,
        time: 0
        event: 'match'
        instance: key: 'direction'
        message:
          user: name: 'jon'
          text: 'left'
      ,
        time: 0
        event: 'match'
        instance: key: 'time'
        message:
          user: name: 'luc'
          text: 'later'
      ,
        time: 0
        event: 'match'
        instance: key: 'direction'
        message:
          user: name: 'luc'
          text: 'right'
      ]

    context 'with record subset matcher', ->

      it 'returns records matching given attributes', ->
        @transcript.findRecords message: user: name: 'jon'
        .should.eql [
          time: 0
          event: 'match'
          instance: key: 'time'
          message:
            user: name: 'jon'
            text: 'now'
        ,
          time: 0
          event: 'match'
          instance: key: 'direction'
          message:
            user: name: 'jon'
            text: 'left'
        ]

    context 'with record subset matcher', ->

      it 'returns only the values at given path', ->
        @transcript.findRecords message: user: name: 'jon', 'message.text'
        .should.eql [ 'now', 'left' ]

  describe '.findKeyMatches', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @transcript.records = [
        time: 0
        event: 'match'
        instance: key: 'pick-a-color'
        response: match: 'blue'.match /(.*)/
        message: user: id: '111', name: 'ami'
      ,
        time: 0
        event: 'match'
        instance: key: 'pick-a-color'
        response: match: 'orange'.match /(.*)/
        message: user: id: '111', name: 'ami'
      ,
        time: 0
        event: 'match'
        instance: key: 'not-a-color'
        response: match: 'up'.match /(.*)/
        message: user: id: '111', name: 'ami'
      ,
        time: 0
        event: 'match'
        instance: key: 'pick-a-color'
        response: match: 'red'.match /(.*)/
        message: user: id: '222', name: 'jon'
    ]

    context 'with an instance key and capture group', ->

      it 'returns the answers matching the key', ->
        @transcript.findKeyMatches('pick-a-color', 0)
        .should.eql ['blue', 'orange', 'red']

    context 'with an instance key, user ID and capture group', ->

      it 'returns the answers matching the key for the user', ->
        @transcript.findKeyMatches('pick-a-color', '111', 0)
        .should.eql ['blue', 'orange']

  ###
  describe '.findIdMatches', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @transcript.records = [
        time: 0
        event: 'match'
        listener: options: id: 'aaa'
        response: match: 'blue'.match /(.*)/
        message: user: id: '111', name: 'ami'
      ,
        time: 0
        event: 'match'
        listener: options: id: 'aaa'
        response: match: 'orange'.match /(.*)/
        message: user: id: '222', name: 'jon'
      ,
        time: 0
        event: 'match'
        listener: options: id: 'bbb'
        response: match: 'foo'.match /(.*)/
        message: user: id: '222', name: 'jon'
      ]

    context 'with a listener ID and capture group', ->

      it 'returns the answers matching the key', ->
        @transcript.findIdMatches('aaa', 0)
        .should.eql ['blue', 'orange']

    context 'with a listener ID, user ID and capture group', ->

      it 'returns the answers matching the key for the user', ->
        @transcript.findIdMatches('aaa', '111', 0)
        .should.eql ['blue']
  ###

  describe 'Usage', ->

    context 'docs example for .findKeyMatches', ->

      beforeEach ->
        @transcript = new Transcript pretend.robot, save: false
        pretend.robot.hear /color/, (res) =>
          favColor = new Dialogue res, 'fav-color'
          @transcript.recordDialogue favColor
          favColor.addPath [
            [ /my favorite color is (.*)/, 'duly noted' ]
          ]
          favColor.receive res
        pretend.robot.respond /what is my favorite color/, (res) =>
          colorMatches = @transcript.findKeyMatches 'fav-color', 1
          # ^ word we're looking for from capture group is at index: 1
          if colorMatches.length
            res.reply "I remember, it's #{ colorMatches.pop() }"
          else
            res.reply "I don't know!?"

      it 'records and recalls favorite color if provided', ->
        yield pretend.user('tim').send('my favorite color is orange')
        yield pretend.user('tim').send('hubot what is my favorite color?')
        pretend.messages.should.eql [
          [ 'testing', 'tester', 'test' ]
          [ 'tim', 'my favorite color is orange' ]
          [ 'hubot', 'duly noted' ]
          [ 'tim', 'hubot what is my favorite color?' ]
          [ 'hubot', '@tim I remember, it\'s orange' ]
        ]
