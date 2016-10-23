util = require 'util'
assert = require 'power-assert'
sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'
chai.should()
chai.use(sinonChai)
expect = chai.expect

# Tests for generic hubot listeners
# This just provide a baseline measure before doing anything complicated

{Robot, TextMessage, User} = require 'hubot'
testUser = new User 'Tester', {room: 'Lobby'}

describe '#Diagnostics', ->

  beforeEach ->
    @bot = new Robot 'hubot/src/adapters', 'shell'
    @spy =
      respond: sinon.spy @bot, 'respond'
      hear: sinon.spy @bot, 'hear'
      response: sinon.spy @bot, 'Response'

    require('../../src/diagnostics') @bot

    @spy.hello = sinon.spy @bot.listeners[0], 'callback'

  afterEach -> @bot.shutdown()

  it 'registers a respond listener', ->
    @spy.respond.should.have.been.calledWith /hello/

  it 'registers a hear listener', ->
    @spy.hear.should.have.been.calledWith /orly/

  it 'creates two listeners', ->
    @bot.listeners.length.should.equal 2

  it 'response created when message matches', ->
    @bot.receive new TextMessage testUser, 'Hubot hello?', '111'
    setTimeout =>
      @spy.response.should.have.been.called # res created
      res = @spy.response.args[0] # TODO - spy res reply?
    , 1000

  it 'respond callback called when message matches', ->
    @bot.receive new TextMessage testUser, 'Hubot hello?', '111'
    setTimeout =>
      @spy.hello.should.have.been.called
      @spy.hello.should.have.been.calledOnce
    , 1000
