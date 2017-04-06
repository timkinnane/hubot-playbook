Q = require 'q'
_ = require 'underscore'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

# Tests for unaltered hubot and its listeners
# This just provides a baseline measure before doing anything complicated

Pretend = require 'hubot-pretend'
pretend = new Pretend "../scripts/diagnostics.coffee"

describe '#Diagnostics', ->

  # Create without helper to test constructors and listeners
  beforeEach ->

    # spy on all responses and all robot methods
    # @response = sinon.spy pretend, 'Response'
    # console.log _.keys(pretend.Robot)
    # sinon.spy pretend.Robot
    # console.log '----------------'
    # _.mapObject pretend.Robot.prototype, (val, key) -> sinon.spy val
    # console.log '----------------'
    #
    # _.mapObject pretend.Robot.__super__, (val, key) ->
    #   console.log key
    #   sinon.spy pretend.Robot.__super__ key
      #  sinon.spy pretend.Robot, key
    # pretend.Robot = sinon.createStubInstance pretend.Robot

    pretend.startup()
    # @robot = pretend.robot
    @user = pretend.user 'tester'

  afterEach ->
    # @response.restore()
    # _.map _.keys(pretend.Robot.prototype), (key) ->
    #   Dialogue.prototype[key].restore()
    #
    # @robot.shutdown()

  context 'script sets up listeners', ->

    it 'registers a respond listener with RegExp and callback', ->
      pretend.robot.respond.should.have.calledWith /which version/i
      pretend.robot.respond.args[0][0].should.be.instanceof RegExp
      pretend.robot.respond.args[0][1].should.be.function

    it 'registers a hear listener with RegExp and callback', ->
      # .hear is also called internally by respond, so test the second call
      pretend.robot.hear.args[1][0].should.be.instanceof RegExp
      pretend.robot.hear.args[1][1].should.be.function

    it 'bot has two listeners', ->
      pretend.robot.listeners.length.should.equal 2

  context 'bot responds to a matching message', ->

    beforeEach ->
      @cb = sinon.spy @robot.listeners[0], 'callback'
      @user.send 'hubot which version'

    it 'bot creates response', ->
      @response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @response

  context 'bot hears a matching message', ->

    beforeEach ->
      @cb = sinon.spy @robot.listeners[1], 'callback'
      @user.send 'Is Hubot listening?'

    it 'bot creates response', ->
      @response.should.have.been.calledOnce

    it 'bot calls callback', ->
      @cb.should.have.been.calledOnce

    it 'callback recieves a response object', ->
      @res = @cb.args[0][0] # get res from callback
      @res.should.be.instanceof @response

  context 'bot responds to its alias', ->

    # rerun module (recreating bot and listeners) with bot alias
    beforeEach ->
      pretend.startup alias: 'buddy'
      @user = pretend.user 'jimbo'
      @cb = sinon.spy pretend.robot.listeners[0], 'callback'
      @user.send 'buddy which version'

    it 'calls callback with response', ->
      @cb.args[0][0].should.be.instanceof @response

  context 'user asks for version number', ->

    beforeEach ->
      @user.send 'hubot which version are you on?'

    it 'replies with a version number', ->
      # console.log pretend.messages
      # console.log pretend.robot.receive.args
      pretend.messages[1][1].should.match /\d.\d.\d/

  context 'user asks a variety of ways if Hubot is listening', ->

    beforeEach ->
      @user.send 'Is Hubot listening?'
      @user.send 'Are any Hubots listening?'
      @user.send 'Is there a bot listening?'
      @user.send 'Hubot are you listening?'

    it 'replies to questions confirming Hubot listening', ->
      @room.messages.length.should.equal 8
