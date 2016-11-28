Q = require 'q'
mute = require 'mute'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

{Robot, TextMessage, User} = require 'hubot'
{EventEmitter} = require 'events'
Helper = require 'hubot-test-helper'
module = "../../src/modules/dialogue"
script = "#{ module }.coffee"
helper = new Helper script
Dialogue = require module
Timeout = setTimeout () ->
  null
, 0
.constructor # get the null Timeout prototype instance for comparison

# prevent environment changing tests
delete process.env.DIALOGUE_TIMEOUT
delete process.env.DIALOGUE_TIMEOUT_LINE

# Tests for user-to-bot / group-to-bot dialogues

describe '#Dialogue', ->

  # Create bot and initiate a response to test with
  beforeEach ->
    @user = new User 'Tester', room: 'Lobby'
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @res = null
    @bot.respond /testing/, (res) => @res = res
    @bot.receive new TextMessage @user, 'Hubot testing', '111'

  afterEach -> @bot.shutdown()

  context 'Create a Dialogue', ->

    beforeEach (done) ->
      Q.delay(200).done =>
        @dialogue = new Dialogue @res
        @spy =
          startTimeout: sinon.spy @dialogue, 'startTimeout'
          clearTimeout: sinon.spy @dialogue, 'clearTimeout'
          onTimeout: sinon.spy @dialogue, 'onTimeout'
          receive: sinon.spy @dialogue, 'receive'
          send: sinon.spy @dialogue, 'send'
          complete: sinon.spy @dialogue, 'complete'
          choice: sinon.spy @dialogue, 'choice'
          getChoices: sinon.spy @dialogue, 'getChoices'
          clearChoices: sinon.spy @dialogue, 'clearChoices'
        done()

    afterEach -> clearTimeout @dialogue.countdown

    it 'inherits event emmiter', ->
      @dialogue.should.be.instanceof EventEmitter
      @dialogue.emit.should.be.instanceof Function

    it 'has the logger from response object robot', ->
      @dialogue.logger.should.eql @bot.logger

    it 'has an empty choices array', ->
      @dialogue.choices.should.be.an 'Array'
      @dialogue.choices.length.should.equal 0

    it 'has config with default', ->
      @dialogue.config.should.be.an 'Object'
      @dialogue.config.timeout.should.equal 30000
      @dialogue.config.timeoutLine.should.equal 'Timed out! Please start again.'

    it 'starts timeout', ->
      @dialogue.countdown.should.exist
      @dialogue.countdown.should.be.instanceof Timeout
