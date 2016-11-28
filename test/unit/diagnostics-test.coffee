Q = require 'q'
mute = require 'mute'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
chai.should()
chai.use require 'sinon-chai'

# Tests for unaltered hubot and its listeners
# This just provide a baseline measure before doing anything complicated
# Really I'm just trying different patterns and utils for testing Hubot
# Many tests use 200ms delay for hubot to process messages

Helper = require 'hubot-test-helper'
module = "../../src/diagnostics"
script = "#{ module }.coffee"
{Robot, TextMessage, User} = require 'hubot'
helper = new Helper script

describe '#Diagnostics', ->

  # Create without helper to test constructors and listeners
  beforeEach ->
    @user = new User 'Tester', room: 'Lobby'
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @spy =
      respond: sinon.spy @bot, 'respond'
      hear: sinon.spy @bot, 'hear'
      response: sinon.spy @bot, 'Response'
    require(module) @bot

  afterEach -> @bot.shutdown()

  context 'Script sets up listeners', ->

    it 'registers a respond listener with RegExp and callback', ->
      @spy.respond.should.have.been.calledWith /which version/i
      @spy.respond.args[0][0].should.be.instanceof RegExp
      @spy.respond.args[0][1].should.be.function

    it 'registers a hear listener with RegExp and callback', ->
      # NB: .hear is also called internally by respond, so test the second call
      @spy.hear.args[1][0].should.be.instanceof RegExp
      @spy.hear.args[1][1].should.be.function

    it 'bot has two listeners', ->
      @bot.listeners.length.should.equal 2

  context 'Bot responds to a matching message', ->

    beforeEach (done) ->
      unmute = mute() # supress hubot messages in test results
      @cb = sinon.spy @bot.listeners[0], 'callback'
      @bot.receive new TextMessage @user, 'Hubot which version', '111'
      Q.delay(200).done =>
        unmute()
        done()

    it 'bot creates response', ->
      @spy.response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @spy.response

  context 'Bot hears a matching message', ->

    beforeEach (done) ->
      unmute = mute() # supress hubot messages in test results
      @cb = sinon.spy @bot.listeners[1], 'callback'
      @bot.receive new TextMessage @user, 'Is Hubot listening?', '111'
      Q.delay(200).done =>
        unmute()
        done()

    it 'bot creates response', ->
      @spy.response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @spy.response

  # TODO: why isn't this covering branch?
  context 'Bot responds to its alias', ->

    # rerun module with an alias'd bot
    beforeEach (done) ->
      @bot = new Robot 'hubot/src/adapters', 'shell'
      @bot.alias = 'buddy'
      require(module) @bot
      @response = sinon.spy @bot, 'Response'
      @cb = sinon.spy @bot.listeners[0], 'callback'
      unmute = mute()
      @bot.receive new TextMessage @user, 'buddy which version', '111'
      Q.delay(200).done =>
        unmute()
        done()

    it 'calls callback with response', ->
      @response.should.have.been.calledOnce
      @cb.should.have.been.calledOnce
      @cb.args[0][0].should.be.instanceof @spy.response

  # Below uses helper for easy messaging tests

  context 'User asks for version number', ->

    beforeEach (done) ->
      @room = helper.createRoom()
      @room.user.say 'Tester', 'Hubot which version are you on?'
      Q.delay(200).done -> done()

    afterEach -> @room.destroy()

    it 'replies with a version number', ->
      @room.messages[1][1].should.match /\d.\d.\d/

  context 'User asks a variety of ways if Hubot is listening', ->

    beforeEach (done) ->
      @room = helper.createRoom()
      @room.user.say 'Tester', 'Is Hubot listening?'
      @room.user.say 'Tester', 'Are any Hubots listening?'
      @room.user.say 'Tester', 'Is there a bot listening?'
      @room.user.say 'Tester', 'Hubot are you listening?'
      Q.delay(200).done -> done()

    afterEach -> @room.destroy()

    it 'reply to qustions confirming Hubot listening', ->
      @room.messages.length.should.equal 8
