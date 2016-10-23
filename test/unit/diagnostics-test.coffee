Q = require 'q'
mute = require 'mute'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'
Helper = require 'hubot-test-helper'
chai.should()
chai.use(sinonChai)
expect = chai.expect

# Tests for unaltered hubot and its listeners
# This just provide a baseline measure before doing anything complicated
# Really I'm just trying different patterns and utils for testing Hubot

module = "../../src/diagnostics"
script = "#{ module }.coffee"
{Robot, TextMessage, User} = require 'hubot'
helper = new Helper script

describe '#Diagnostics', ->

  beforeEach ->

    # Create without helper to test constructors and listeners
    @user = new User 'Tester', {room: 'Lobby'}
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @spy =
      respond: sinon.spy @bot, 'respond'
      hear: sinon.spy @bot, 'hear'
      response: sinon.spy @bot, 'Response'
    require(module) @bot

    # Create helper to test messaging after listeners set up
    @room = helper.createRoom()

  afterEach ->
    @bot.shutdown()
    @room.destroy()

  context 'Script sets up listeners', ->

    it 'registers a respond listener', ->
      @spy.respond.should.have.been.calledWith /which version/i

    it 'registers a hear listener with RegExp', ->
      @spy.hear.args[1][0].should.be instanceof RegExp

    it 'bot has two listeners', ->
      @bot.listeners.length.should.equal 2

  context 'Bot responds to a matching message', ->

    beforeEach (done) ->
      unmute = mute() # supress hubot messages in test results
      @cb = sinon.spy @bot.listeners[0], 'callback'
      @bot.receive new TextMessage @user, 'hubot which version', '111'
      Q.delay(500).done =>
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
      @bot.receive new TextMessage @user, 'is hubot listening?', '111'
      Q.delay(500).done =>
        unmute()
        done()

    it 'bot creates response', ->
      @spy.response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @spy.response

  # context 'User asks for diagnostic responses', ->
