_ = require 'lodash'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
co = require 'co'
chai.use require 'sinon-chai'
pretend = require 'hubot-pretend'

# Tests for unaltered hubot and its listeners.
# This just provides a baseline measure before doing anything complicated.
# Some fairly unnessecary stuff here as example of unit testing approaches.

# NB Test functions that end with a call to `.send` return a promise, which the
# function will implicitly wait for without needing to yield. Any async calls
# within tests that aren't returned *do* need to yield before making assertions.
# TODO Document the above somewhere more prominent

# Response objects can be extended and proxied, so it's hard to do a straight
# match with `instanceOf`, we just check they've got the right keys instead.
matchRes = (value) ->
  responseKeys = [ 'robot', 'message', 'match', 'envelope' ]
  difference = _.difference responseKeys, _.keys value
  difference.length == 0

describe 'Diagnostics', ->

  beforeEach ->
    pretend.read('test/scripts/diagnostics.coffee').start()

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
      pretend.user('tester').send 'hubot which version'

    it 'bot creates response', ->
      pretend.responses.listen.length.should.equal 1

    it 'bot calls listener callback with response', ->
      @cb.should.have.calledWithMatch sinon.match matchRes

  context 'bot hears a matching message', ->

    beforeEach ->
      @cb = sinon.spy pretend.robot.listeners[1], 'callback'
      pretend.user('tester').send 'Is Hubot listening?'

    it 'bot creates response', ->
      pretend.responses.listen.length.should.equal 1

    it 'bot calls listener callback with response', ->
      @cb.should.have.calledWithMatch sinon.match matchRes

  context 'bot responds to its alias', ->

    # rerun module (recreating bot and listeners) with bot alias
    beforeEach ->
      pretend.startup alias: 'buddy'
      @cb = sinon.spy pretend.robot.listeners[0], 'callback'
      pretend.user('jimbo').send 'buddy which version'

    it 'calls callback with response', ->
      @cb.should.have.calledWithMatch sinon.match matchRes

  context 'user asks for version number', ->

    beforeEach ->
      pretend.user('jimbo').send 'hubot which version are you on?'

    it 'replies to tester with a version number', ->
      pretend.messages[1][1].should.match /jimbo .*\d+.\d+.\d+/

  context 'user asks different ways if Hubot is listening', ->

    beforeEach -> co ->
      yield pretend.user('jimbo').send 'Are any Hubots listening?'
      yield pretend.user('jimbo').send 'Is there a bot listening?'

    it 'replies to each confirming Hubot listening', ->
      pretend.messages[1].should.eql pretend.messages[3]
