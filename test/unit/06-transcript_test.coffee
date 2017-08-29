sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'
co = require 'co'
_ = require 'lodash'
pretend = require 'hubot-pretend'
Transcript = require '../../lib/modules/transcript.js'
Director = require '../../lib/modules/director.js'
Scene = require '../../lib/modules/scene.js'
Dialogue = require '../../lib/modules/dialogue.js'
Base = require '../../lib/modules/base.js'
Module = require '../../lib/utils/module.js'

# helper clears existing listeners to check specific listeners are added
removeListeners = (robot) -> robot.events.removeAllListeners.apply robot

clock = null

describe 'Transcript', ->

  beforeEach ->
    pretend.start()
    clock = sinon.useFakeTimers()

    Object.getOwnPropertyNames(Transcript.prototype).map (key) ->
      sinon.spy Transcript.prototype, key

  afterEach ->
    pretend.shutdown()
    clock.restore()

    Object.getOwnPropertyNames(Transcript.prototype).map (key) ->
      Transcript.prototype[key].restore()

  describe 'constructor', ->

    context 'with saving enabled (default)', ->

      beforeEach ->
        pretend.robot.brain.set 'transcripts', [ time: 0, event: 'test' ]
        @transcript = new Transcript pretend.robot

      it 'uses brain for record keeping', ->
        @transcript.records.should.eql [ time: 0, event: 'test' ]

    context 'with saving disabled', ->

      beforeEach ->
        pretend.robot.brain.set 'transcripts', [ time: 0, event: 'test' ]
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
          time: 0
          event: 'mockEvent'
          other: [ test: 'data' ]
        ]

    context 'emitted from Playbook module', ->

      beforeEach ->
        @transcript = new Transcript pretend.robot, save: false
        @module = new Module pretend.robot, 'foo'
        @module.on 'mockEvent', (args...) =>
          @transcript.recordEvent 'mockEvent', @module, args...

      context 'with default config', ->

        it 'records default instance attributes', (done) ->
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset instance:
              name: @module.name
              key: @module.key
              id: @module.id
            done()
          @module.emit 'mockEvent', pretend.response 'tester', 'test'

        it 'records default response attributes', (done) ->
          res = pretend.response 'tester', 'test'
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset response:
              match: res.match
            done()
          @module.emit 'mockEvent', res

        it 'records default message attributes', (done) ->
          res = pretend.response 'tester', 'test', 'testing'
          @transcript.on 'record', =>
            @transcript.records[0].should.containSubset message:
              user:
                id: res.message.user.id
                name: res.message.user.name
              room: res.message.room
              text: res.message.text
            done()
          @module.emit 'mockEvent', pretend.response 'tester', 'test'

      context 'with transcript key', ->

        beforeEach ->
          @transcript.key = 'test-key'
          @module.emit 'mockEvent', pretend.response 'tester', 'test'

        it 'records event with key property', ->
          @transcript.records[0].should.have.property 'key', 'test-key'

      context 'with custom instance atts', ->

        beforeEach ->
          @transcript.config.instanceAtts = ['name', 'config.scope']
          @module.config.scope = 'whitelist' # act like a director for this one
          @module.emit 'mockEvent', pretend.response 'tester', 'test'

        it 'records custom instance attributes', ->
          @transcript.records[0].should.containSubset instance:
            name: @module.name
            config: scope: @module.config.scope

      context 'with custom response atts', ->

        beforeEach ->
          @transcript.config.responseAtts = ['message.room']
          @module.emit 'mockEvent', pretend.response 'tester', 'test', 'testing'

        it 'records custom response attributes', ->
          @transcript.records[0].should.containSubset response:
            message: room: 'testing'

      context 'with custom message atts', ->

        beforeEach ->
          @transcript.config.messageAtts = 'room'
          @module.emit 'mockEvent', pretend.response 'tester', 'test', 'testing'

        it 'records custom message attributes', ->
          @transcript.records[0].should.containSubset message:
            room: 'testing'

      context 'on event without res argument', ->

        beforeEach ->
          @module.emit 'mockEvent'

        it 'records event without response or other attributes', ->
          @transcript.records.should.eql [
            time: 0
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
            time: 0
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
        @transcript.recordEvent.args.should.eql [ ['foo'], ['bar'] ]

  describe '.recordDialogue', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @dialogue = new Dialogue pretend.response 'tester', 'test'

    context 'with default event set', ->

      beforeEach (done) ->
        removeListeners pretend.robot
        @transcript.recordDialogue @dialogue
        @dialogue.addPath [ [ /test/, -> ] ]
        @dialogue.path.on 'match', -> done()
        @dialogue.path.emit 'match'

      it 'attached listener for default events from dialogue and path', ->
        expectedEvents = @transcript.config.events
        expectedEvents.push 'path' # path event always added by recordDialogue
        _.keys pretend.robot._events
        .should.have.members expectedEvents

      it 'calls the listener when event emited from dialogue path', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue.path

    context 'with custom event set', ->

      beforeEach (done) ->
        removeListeners pretend.robot
        @transcript.config.events = ['match', 'mismatch', 'end']
        @transcript.recordDialogue @dialogue
        @dialogue.addPath [ [ /test/, -> ] ]
        @dialogue.emit 'send'
        @dialogue.emit 'end'
        @dialogue.path.on 'match', -> done()
        @dialogue.path.emit 'match'

      it 'attached listener for default events from dialogue and path', ->
        _.keys pretend.robot._events
        .should.have.members ['match', 'mismatch', 'end', 'path']

      it 'calls the listener when event emited from dialogue', ->
        @transcript.recordEvent.should.have.calledWith 'end', @dialogue

      it 'calls the listener when event emited from path', ->
        @transcript.recordEvent.should.have.calledWith 'match', @dialogue.path

      it 'does not call with any unconfigured events', ->
        @transcript.recordEvent.should.not.have.calledWith 'send', @dialogue

  describe '.recordScene', ->

    it 'records events emitted by scene, its dialogues and paths', -> co ->
      res = pretend.response 'tester', 'test'
      removeListeners pretend.robot
      transcript = new Transcript pretend.robot,
        save: false,
        events: [ 'enter', 'match', 'send' ]
      scene = new Scene pretend.robot
      transcript.recordScene scene
      dialogue = scene.enter res
      dialogue.addBranch /test/, 'response'
      yield dialogue.receive res
      records = transcript.recordEvent.args.map((record) -> _.take(record, 2))
      records.should.eql [
        [ 'enter', scene ]
        [ 'match', dialogue.path ]
        [ 'send', dialogue ]
      ]

  describe '.recordDirector', ->

    beforeEach (done) ->
      @res = pretend.response 'tester', 'test'
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

  describe 'Usage', ->

    context 'record scene with one specific path key', ->

      it 'uses scene key for dialogue and all paths except one', -> co ->
        transcript = new Transcript pretend.robot, save: false
        transcript.configure
          events: [ 'match', 'catch' ]
          instanceAtts: [ 'key' ]
          responseAtts: null
        scene = new Scene pretend.robot, 'looking-for-treasure'
        transcript.recordScene scene, scope: 'direct'
        scene.hear /enter/, (res) ->
          res.dialogue.addPath 'You\'re in! Pick door 1, 2 or 3', [
            [ /door 1/, 'You lose - bad luck!' ]
            [ /door 2/, 'You lose - bad luck!' ]
            [ /door 3/, (res) ->
              res.dialogue.addPath 'OK, upstairs or downstairs?', [
                [ /upstairs/, 'You lose - bad luck!' ]
                [ /downstairs/, (res) ->
                  res.dialogue.addPath 'Last question, left or right?', [
                    [ /left/, 'You found the treasure - well done!' ]
                    [ /right/, 'You lose - bad luck!' ]
                  ], 'final-room'
                ]
              ]
            ]
          ], catchMessage: 'Pick "door 1", "door 2" or "door 3"'
        # ... run contestants
        yield pretend.user('frodo').send 'enter'
        yield pretend.user('bilbo').send 'enter'
        yield pretend.user('frodo').send 'how?'
        yield pretend.user('frodo').send 'door 1'
        yield pretend.user('gimli').send 'enter'
        yield pretend.user('gimli').send 'door 3'
        yield pretend.user('gimli').send 'downstairs'
        yield pretend.user('gimli').send 'left'
        # .. compile report
        steps = transcript.records.map (record) -> [
          record.event
          record.instance.key
          record.message.user.name
          record.message.text
        ]
        steps.should.eql [
          [ 'catch', 'looking-for-treasure', 'frodo', 'how?' ],
          [ 'match', 'looking-for-treasure', 'frodo', 'door 1' ],
          [ 'match', 'looking-for-treasure', 'gimli', 'door 3' ],
          [ 'match', 'looking-for-treasure', 'gimli', 'downstairs' ],
          [ 'match', 'final-room', 'gimli', 'left' ]
        ]

    context 'docs example for .findKeyMatches', ->

      it 'records and recalls favorite color if provided', -> co ->
        transcript = new Transcript pretend.robot, save: false
        pretend.robot.respond /what is my favorite color/, (res) ->
          colorMatches = transcript.findKeyMatches 'fav-color', 1
          if colorMatches.length
            res.reply "I remember, it's #{ colorMatches.pop() }"
          else
            res.reply "I don't know!?"

        dialogue = new Dialogue pretend.response 'tester', 'test'
        transcript.recordDialogue dialogue
        dialogue.addPath [
          [ /my favorite color is (.*)/, 'duly noted' ]
        ], 'fav-color'
        dialogue.receive pretend.response 'tim', 'my favorite color is orange'

        yield pretend.user('tim').send 'my favorite color is orange'
        yield pretend.user('tim').send 'hubot what is my favorite color?'
        pretend.messages.should.eql [
          [ 'tim', 'my favorite color is orange' ]
          [ 'hubot', 'duly noted' ]
          [ 'tim', 'hubot what is my favorite color?' ]
          [ 'hubot', '@tim I remember, it\'s orange' ]
        ]
###
