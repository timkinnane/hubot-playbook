sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'

_ = require 'lodash'
co = require 'co'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Transcript, Dialogue, Base} = require '../../src/modules'

describe 'Transcript', ->

  beforeEach ->
    pretend.startup()
    @tester = pretend.user 'tester', id:'tester', room: 'testing'
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

        beforeEach ->
          @module.emit 'mockEvent', @res

        it 'records default instance attributes', ->
          @transcript.records[0].should.containSubset instance:
            name: @module.name
            key: @module.config.key
            id: @module.id

        it 'records default response attributes', ->


      context 'with transcript key', ->
      context 'with custom instance atts', ->
      context 'with custom response atts', ->
      context 'without res argument', ->
      context 'with invalid custom atts', ->

  describe '.recordAll', ->

    context 'with default event set', ->

    context 'with custom event set', ->

  describe 'recordDialogue', ->

    beforeEach ->
      @transcript = new Transcript pretend.robot, save: false
      @dialogue = new Dialogue pretend.robot
      @dialogue.addPath '', [
        [ /left/, 'Ok, going left!' ]
        [ /right/, 'Ok, going right!' ]
      ],
        key: 'which-way'
        error: 'Bzz. Left or right only!'

    context 'with default event set', ->

    context 'with custom event set', ->

### copied from old Dialogue tests...

  describe '.record', ->

    beforeEach ->
      @match = sinon.spy()
      @mismatch = sinon.spy()
      @dialogue.on 'match', @match
      @dialogue.on 'mismatch', @mismatch
      @key = @dialogue.path
        prompt: 'Turn left or right?'
        branches: [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        key: 'which-way'
        error: 'Bzz. Left or right only!'

    context 'with arguments from the sent prompt', ->

      it 'adds match type, "bot" and content to transcript', ->
        @dialogue.paths[@key].transcript[0].should.eql [
          'send'
          'bot'
          'Turn left or right?'
        ]

    context 'with arguments from a matched choice', ->

      beforeEach ->
        @tester.send 'left'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'match'
          @rec.message.user
          'left'
        ]

      it 'emits mismatch event with user, content', ->
        @match.should.have.calledWith @rec.message.user, 'left'

    context 'with arguments from a mismatched choice', ->

      beforeEach ->
        @tester.send 'up'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'mismatch'
          @rec.message.user
          'up'
        ]

      it 'emits mismatch event with user, content', ->
        @mismatch.should.have.calledWith @rec.message.user, 'up'

###
