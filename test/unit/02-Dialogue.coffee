Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../utils/noScript.coffee"
Dialogue = require "../../src/modules/Dialogue"
{TextMessage, User, Response} = require 'hubot'
{EventEmitter} = require 'events'
Timeout = setTimeout () ->
  null
, 0
.constructor # get the null Timeout prototype instance for comparison

# prevent environment changing tests
delete process.env.DIALOGUE_TIMEOUT
delete process.env.DIALOGUE_TIMEOUT_LINE

describe '#Dialogue', ->

  # Create bot and initiate a response to test with
  beforeEach (done) ->
    @room = helper.createRoom()
    @res = null
    @room.robot.respond /testing/, (res) => @res = res
    @room.user.say 'user1', 'hubot testing' # start dialogue
    @spy = _.mapObject Dialogue.prototype, (val, key) ->
      sinon.spy Dialogue.prototype, key # spy on all the class methods
    Q.delay(100).done -> done() # let it process the messages and create res

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  context 'created with defaults', ->

    beforeEach -> @dialogue = new Dialogue @res
    afterEach -> clearTimeout @dialogue.countdown

    it 'inherits event emmiter', ->
      @dialogue.should.be.instanceof EventEmitter
      @dialogue.emit.should.be.a 'function'

    it 'has the logger from response object robot', ->
      @dialogue.logger.should.eql @room.robot.logger

    it 'has an empty choices array', ->
      @dialogue.choices.should.be.an 'array'
      @dialogue.choices.length.should.equal 0

    it 'has config with defaults of correct type', ->
      @dialogue.config.should.be.an 'object'
      @dialogue.config.timeout.should.be.a 'number'
      @dialogue.config.timeoutLine.should.be.a 'string'

    it 'starts timeout', ->
      @dialogue.countdown.should.exist
      @dialogue.countdown.should.be.instanceof Timeout
      @dialogue.countdown._called.should.be.false
      @spy.startTimeout.should.have.been.calledOnce

  context 'created with env vars', ->

    beforeEach ->
      process.env.DIALOGUE_TIMEOUT = 500
      process.env.DIALOGUE_TIMEOUT_LINE = 'Testing timeout env'
      @dialogue = new Dialogue @res
    afterEach ->
      clearTimeout @dialogue.countdown
      delete process.env.DIALOGUE_TIMEOUT
      delete process.env.DIALOGUE_TIMEOUT_LINE

    it 'uses the environment timeout settings', ->
      @dialogue.config.timeout.should.equal 500
      @dialogue.config.timeoutLine.should.equal 'Testing timeout env'

  context 'created with options', ->

    beforeEach ->
      @dialogue = new Dialogue @res,
        timeout: 555
        timeoutLine: 'Testing timeout options'
    afterEach -> clearTimeout @dialogue.countdown

    it 'uses the passed options timeout settings', ->
      @dialogue.config.timeout.should.equal 555
      @dialogue.config.timeoutLine.should.equal 'Testing timeout options'

  context 'created with 100ms timeout', ->

    beforeEach (done) ->
      @eventSpy = sinon.spy()
      @dialogue = new Dialogue @res, timeout: 100
      @dialogue.on 'timeout', @eventSpy
      Q.delay(110).done -> done()
    afterEach -> clearTimeout @dialogue.countdown

    it 'emits timeout event', ->
      @eventSpy.should.have.been.calledOnce

    it 'calls onTimeout with response object', ->
      @spy.onTimeout.should.have.been.calledOnce
      @spy.onTimeout.should.have.been.calledWith @res

    it 'clears internal timeout counter', ->
      @dialogue.countdown._called.should.be.true

    it 'sends timout message to room', ->
      @room.messages.should.eql [
        [ 'user1', 'hubot testing' ],
        [ 'hubot', @dialogue.config.timeoutLine ]
      ]

  context 'created with all variations of choice', ->

    beforeEach ->
      unmute = mute() # don't write logs amongst test results
      @dialogue = new Dialogue @res
      @user = new User 'user1', room: 'test'
      @errorSpy = sinon.spy @room.robot.logger, 'error'
      @debugSpy = sinon.spy @dialogue.logger, 'debug'

      # create four choices, first three are valid
      # prepare a message, match and response objects for each choice
      # these will be received directly by dialogue, not through @room
      # NB: Dialogue doesn't attach the middleware to pass along a message

      # door number 1
      @prize1 = 'Nothing'
      @dialogue.choice /number 1/i, @prize1
      @handler1 = sinon.spy @dialogue.choices[0], 'handler'
      msg = new TextMessage @user, 'Door number 1', '1'
      match = msg.text.match @dialogue.choices[0].regex
      @res1 = new Response @room.robot, msg, match

      # door number 2
      @dialogue.choice /number 2/i, () -> null
      @handler2 = sinon.spy @dialogue.choices[1], 'handler'
      msg = new TextMessage @user, 'Door number 2', '1'
      match = msg.text.match @dialogue.choices[1].regex
      @res2 = new Response @room.robot, msg, match

      # door number 3
      @prize3 = 'Booby Prize'
      @prize3Spy = sinon.spy()
      @dialogue.choice /number 3/i, @prize3, @prize3Spy
      @handler3 = sinon.spy @dialogue.choices[2], 'handler'
      msg = new TextMessage @user, 'Door number 3', '1'
      match = msg.text.match @dialogue.choices[2].regex
      @res3 = new Response @room.robot, msg, match

      # false door
      @dialogue.choice /number 4/i, null

      unmute()
    afterEach ->
      @handler1.restore()
      @handler2.restore()
      @handler3.restore()
      clearTimeout @dialogue.countdown

    it 'clear and restart the timeout each time', ->
      @spy.clearTimeout.should.have.callCount 3
      @spy.startTimeout.should.have.callCount 4 # called on init

    it 'remember three (of four) valid choices', ->
      @dialogue.choices.should.be.an 'array'
      @dialogue.choices.length.should.equal 3

    it 'getChoices returns the array of choices', ->
      @dialogue.getChoices().should.eql @dialogue.choices

    it 'clearChoices clears the array of choices', ->
      @dialogue.clearChoices()
      @dialogue.choices.should.be.an 'array'
      @dialogue.choices.length.should.equal 0

    it 'has object with listener and handler for each valid choice', ->
      _.each @dialogue.choices, (choice) =>
        choice.should.be.an 'object'
        choice.regex.should.be.instanceof RegExp
        choice.handler.should.be.a 'function'

    it 'log an error for incorrect args', ->
      @errorSpy.should.have.been.calledOnce

    it 'match choice 1 with default callback, sends message', ->
      @dialogue.receive @res1
      .then =>
        @handler1.should.have.been.calledOnce
        @debugSpy.should.have.been.called # log at least something
        @room.messages.pop().should.eql [ 'hubot', @prize1 ]

    it 'match choice 2 with custom callback', ->
      @dialogue.receive @res2
      .then =>
        @handler2.should.have.been.calledOnce

    it 'match choice 3 with custom callback', ->
      @dialogue.receive @res3
      .then =>
        @handler3.should.have.been.calledOnce
        @prize3Spy.should.have.been.calledOnce
        @room.messages.pop().should.eql [ 'hubot', @prize3 ]

    it 'clears choices after match', ->
      @dialogue.receive @res1
      .then => @spy.clearChoices.should.have.been.calledOnce

    it 'does not match more than once', ->
      Q.all [
        @dialogue.receive @res1
        @dialogue.receive @res3
      ]
      .then =>
        @spy.clearChoices.should.have.been.calledOnce
        @room.messages.pop().should.eql [ 'hubot', @prize1 ]

  context 'add another choice with matched choice callback', ->

    beforeEach ->
      unmute = mute()
      @dialogue = new Dialogue @res
      @user = new User 'user1', room: 'test'
      @yesSpy = sinon.spy()
      @dialogue.choice /confirm/, () => @dialogue.choice /yes/i, @yesSpy
      msg1 = new TextMessage @user, 'confirm', '1'
      match1 = msg1.text.match @dialogue.choices[0].regex
      @res1 = new Response @room.robot, msg1, match1
      msg2 = new TextMessage @user, 'yes', '1'
      match2 = msg2.text.match @dialogue.choices[0].regex
      @res2 = new Response @room.robot, msg2, match2
      unmute()

    afterEach -> clearTimeout @dialogue.countdown

    it 'has new choice after matching original', ->
      @dialogue.receive @res1
      .then => @dialogue.choices.length.should.equal 1

    it 'calls second callback after matching sequence', ->
      @dialogue.receive @res1
      .then => @dialogue.receive @res2
      .then => @yesSpy.should.have.been.calledOnce
