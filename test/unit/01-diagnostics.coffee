Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

# Tests for unaltered hubot and its listeners
# This just provide a baseline measure before doing anything complicated
# Really I'm just trying different patterns and utils for testing Hubot
# Note: @bot.receive tests use `done` callback, @room.say tests return promise

Helper = require 'hubot-test-helper'
module = "../../src/diagnostics"
script = "#{ module }.coffee"
{Robot, TextMessage, User} = require 'hubot'
helper = new Helper script

describe '#Diagnostics', ->

  # Create without helper to test constructors and listeners
  beforeEach ->
    @user = new User 'Tester', room: 'Lobby'
    @spy =
      hear: sinon.spy Robot.prototype, 'hear'
      respond: sinon.spy Robot.prototype, 'respond'
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @bot.alias = null
    @spy.response = sinon.spy @bot, 'Response' # sub-constructors after init
    require(module) @bot

  afterEach ->
    _.invoke @spy, 'restore' # remove all spies so they can be reattached clean
    @bot.shutdown()

  context 'script sets up listeners', ->

    it 'registers a respond listener with RegExp and callback', ->
      @spy.respond.should.have.been.calledWith /which version/i
      @spy.respond.args[0][0].should.be.instanceof RegExp
      @spy.respond.args[0][1].should.be.function

    it 'registers a hear listener with RegExp and callback', ->
      # .hear is also called internally by respond, so test the second call
      @spy.hear.args[1][0].should.be.instanceof RegExp
      @spy.hear.args[1][1].should.be.function

    it 'bot has two listeners', ->
      @bot.listeners.length.should.equal 2

  context 'bot responds to a matching message', ->

    beforeEach (done) ->
      unmute = mute() # supress hubot messages in test results
      @cb = sinon.spy @bot.listeners[0], 'callback'
      msg = new TextMessage @user, 'Hubot which version', '111'
      @bot.receive msg, () -> done()

    it 'bot creates response', ->
      @spy.response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @spy.response

  context 'bot hears a matching message', ->

    beforeEach (done) ->
      unmute = mute() # supress hubot messages in test results
      @cb = sinon.spy @bot.listeners[1], 'callback'
      msg = new TextMessage @user, 'Is Hubot listening?', '111'
      @bot.receive msg, () ->
        unmute()
        done()

    it 'bot creates response', ->
      @spy.response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @spy.response

  context 'bot responds to its alias', ->

    # rerun module (recreating bot and listeners) with bot alias
    beforeEach (done) ->
      @bot = new Robot 'hubot/src/adapters', 'shell'
      @bot.alias = 'buddy'
      @spy.response = sinon.spy @bot, 'Response' # sub-constructors after init
      require(module) @bot
      @cb = sinon.spy @bot.listeners[0], 'callback'
      unmute = mute()
      msg = new TextMessage @user, 'buddy which version', '111'
      @bot.receive msg, () ->
        unmute()
        done()

    it 'calls callback with response', ->
      @spy.response.should.have.been.calledOnce
      @cb.should.have.been.calledOnce
      @cb.args[0][0].should.be.instanceof @spy.response

  # Below uses helper for easy messaging tests

  context 'user asks for version number', ->

    beforeEach ->
      @room = helper.createRoom()
      @room.user.say 'Tester', 'Hubot which version are you on?'

    afterEach -> @room.destroy()

    it 'replies with a version number', ->
      @room.messages[1][1].should.match /\d.\d.\d/

  context 'user asks a variety of ways if Hubot is listening', ->

    beforeEach ->
      @room = helper.createRoom()
      @room.user.say 'Tester', 'Is Hubot listening?'
      .then => @room.user.say 'Tester', 'Are any Hubots listening?'
      .then => @room.user.say 'Tester', 'Is there a bot listening?'
      .then => @room.user.say 'Tester', 'Hubot are you listening?'

    afterEach -> @room.destroy()

    it 'replies to questions confirming Hubot listening', ->
      @room.messages.length.should.equal 8
