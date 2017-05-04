sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

co = require 'co'

# Tests for unaltered hubot and its listeners
# This just provides a baseline measure before doing anything complicated
# Doing some fairly unnessecary stuff here as example of unit testing approaches

Pretend = require 'hubot-pretend'
pretend = new Pretend "../scripts/diagnostics.coffee"

describe 'Diagnostics', ->

  beforeEach ->
    pretend.startup()
    @user = pretend.user 'tester'

  context 'script sets up a "respond" and a "hear" listener', ->

    it 'robot.respond called once to set up listener', ->
      pretend.robot.respond.should.have.calledOnce

    it 'registers a respond listener with RegExp and function', ->
      pretend.robot.respond.getCall(0)
      .should.have.calledWithMatch sinon.match.regexp, sinon.match.func

    it 'robot.hear called twice (by respond then directly)', ->
      pretend.robot.hear.should.have.calledTwice

    it 'registers a hear listener with RegExp and callback (no options)', ->
      pretend.robot.hear.getCall(1)
      .should.have.calledWithMatch sinon.match.regexp, sinon.match.func

    it 'robbot has two listeners', ->
      pretend.robot.listeners.length.should.equal 2

  context 'bot responds to a matching message', ->

    beforeEach ->
      @cb = sinon.spy pretend.robot.listeners[0], 'callback'
      @user.send 'hubot which version'

    it 'bot creates response', ->
      pretend.responses.incoming.length.should.equal 1

    it 'bot calls listener callback with response', ->
      @cb.should.have.calledWithMatch sinon.match.instanceOf pretend.Response

  context 'bot hears a matching message', ->

    beforeEach ->
      @cb = sinon.spy pretend.robot.listeners[1], 'callback'
      @user.send 'Is Hubot listening?'

    it 'bot creates response', ->
      pretend.responses.incoming.length.should.equal 1

    it 'bot calls listener callback with response', ->
      @cb.should.have.calledWithMatch sinon.match.instanceOf pretend.Response

  context 'bot responds to its alias', ->

    # rerun module (recreating bot and listeners) with bot alias
    beforeEach ->
      pretend.startup alias: 'buddy'
      @cb = sinon.spy pretend.robot.listeners[0], 'callback'
      @user = pretend.user 'jimbo'
      @user.send 'buddy which version'

    it 'calls callback with response', ->
      @cb.should.have.calledWithMatch sinon.match.instanceOf pretend.Response

  context 'user asks for version number', ->

    beforeEach ->
      @user.send 'hubot which version are you on?'

    it 'replies to tester with a version number', ->
      pretend.messages[1][1].should.match /@tester .*\d+.\d+.\d+/

  context 'user asks different ways if Hubot is listening', ->

    beforeEach ->
      co =>
        yield @user.send 'Are any Hubots listening?'
        yield @user.send 'Is there a bot listening?'

    it 'replies to each confirming Hubot listening', ->
      pretend.messages[1].should.eql pretend.messages[3]
