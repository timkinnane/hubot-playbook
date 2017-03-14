Q = require 'q'
_ = require 'underscore'
{generate} = require 'randomstring'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

{Robot, User, TextMessage} = require 'hubot'
Playbook = require '../../src/Playbook'

# TODO: Add example usage of directed scenes

describe 'Playbook usage (messaging test cases)', ->

  before ->
    # helper to send messages to bot, returns promise
    @send = (user, text) =>
      unmute = mute()
      deferred = Q.defer()
      msg = new TextMessage user, text, generate 6 # random id
      @robot.receive msg, -> deferred.resolve() # resolve as callback
      return deferred.promise.then -> unmute()
    # same username in two rooms should be recognised as same user
    @nimaInA = new User 1,
      name: 'nima'
      room: '#A'
    @pemaInA = new User 2,
      name: 'pema'
      room: '#A'
    @nimaInB = new User 1,
      name: 'nima'
      room: '#B'
    @pemaInB = new User 2,
      name: 'pema'
      room: '#B'

  beforeEach ->
    # prepare robot to store every message
    @messages = []
    @robot = new Robot 'hubot/src/adapters', 'shell'
    require('../scripts/ping.coffee') @robot # run hubot through test script
    @robot.on 'receive', (res) =>
      msg = res.message if res.message instanceof TextMessage
      @messages.push [ msg.room, msg.user.name, msg.text ] if msg?
    @robot.on 'respond', (res, strings) =>
      msg = res.message if res.message instanceof TextMessage and strings?
      @messages.push [ msg.room, 'hubot', strings[0] ] if msg?
    @robot.logger.info = @robot.logger.debug = -> # silence

    # fire it up
    @playbook = new Playbook @robot

  afterEach ->
    @playbook.shutdown()
    @robot.shutdown()

  context 'knock knock test - user scene', ->

    beforeEach ->
      @playbook.sceneHear /knock/, 'user', ->
        @send "Who's there?"
        @branch /.*/, (res) =>
          @send "#{ res.match[0] } who?"
          @branch /.*/, "Hello #{ res.match[0] }"

    context 'Nima begins in A, continues in B, Pema tries in both', ->

      beforeEach ->
        @send @nimaInA, "knock knock" # ...Who's there?
        .then => @send @pemaInA, "Pema in A" # ...ignored
        .then => @send @nimaInB, "Nima in B" # ...Nima in B who?
        .then => @send @pemaInB, "Pema in B" # ...ignored

      it 'responds to Nima in both, ignores Pema in both', ->
        @messages.should.eql [
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "Who's there?" ],
          [ '#A', 'pema', "Pema in A" ],
          [ '#B', 'nima', "Nima in B" ],
          [ '#A', 'hubot', "Nima in B who?" ],
          [ '#B', 'pema', "Pema in B" ]
        ]

  context 'knock knock test - room scene', ->

    beforeEach ->
      @playbook.sceneHear /knock/, 'room', ->
        @send "Who's there?"
        @branch /.*/, (res) =>
          @send "#{ res.match[0] } who?"
          @branch /.*/, (res) =>
            @send "Hello #{ res.match[0] }"

    context 'Nima begins in A, continues in B, Pema responds in A', ->

      beforeEach ->
        @send @nimaInA, "knock knock" # ...Who's there?
        .then => @send @nimaInB, "Nima" # ...ignored
        .then => @send @pemaInA, "Pema" # ...Pema who?
        .then => @send @pemaInB, "Pema in B" # ...ignored
        .then => @send @nimaInA, "No it's Nima" # No it"s Nima who?
        .then => @send @pemaInA, "Hey!?" # ...ignored

      it 'responds to Nima or Pema in A, ignores both in B', ->
        @messages.should.eql [
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "Who's there?" ],
          [ '#B', 'nima', "Nima" ],
          [ '#A', 'pema', "Pema" ],
          [ '#A', 'hubot', "Pema who?" ],
          [ '#B', 'pema', "Pema in B" ],
          [ '#A', 'nima', "No it's Nima" ],
          [ '#A', 'hubot', "Hello No it's Nima" ],
          [ '#A', 'pema', "Hey!?" ]
        ]

  context 'knock knock test - direct scene', ->

    beforeEach ->
      @playbook.sceneHear /knock/, 'direct', ->
        @send "Who's there?"
        @branch /.*/, (res) =>
          @send "#{ res.match[0] } who?"
          @branch /.*/, (res) =>
            @send "Hello #{ res.match[0] }"

    context 'Nima begins in A, continues in both, Pema responds in A', ->

      beforeEach ->
        @send @nimaInA, "knock knock" # ...Who's there?
        .then => @send @nimaInB, "Nima" # ...ignored
        .then => @send @pemaInA, "Pema" # ...ignored
        .then => @send @pemaInB, "Pema in B" # ...ignored
        .then => @send @nimaInA, "Nima" # Nima who?
        .then => @send @nimaInA, "Nima in A" # Hello Nima in A

      it 'responds only to Nima in A, ignores both in B', ->
        @messages.should.eql [
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "Who's there?" ],
          [ '#B', 'nima', "Nima" ],
          [ '#A', 'pema', "Pema" ],
          [ '#B', 'pema', "Pema in B" ],
          [ '#A', 'nima', "Nima" ],
          [ '#A', 'hubot', "Nima who?" ],
          [ '#A', 'nima', "Nima in A" ],
          [ '#A', 'hubot', "Hello Nima in A" ],
        ]

  context 'knock knock test - parallel direct scenes + reply', ->

    beforeEach ->
      @playbook.sceneHear /knock/, 'direct', reply: true, ->
        @send "Who's there?"
        @branch /.*/, (res) =>
          @send "#{ res.match[0] } who?"
          @branch /.*/, (res) =>
            @send "Hello #{ res.match[0] }"

    context 'Nima begins, Pema begins, both continue in same room', ->

      beforeEach ->
        @send @nimaInA, "knock knock" # ...Who's there?
        .then => @send @pemaInA, "knock knock" # ...Who's there?
        .then => @send @nimaInA, "Nima" # ...Nima who?
        .then => @send @pemaInA, "Pema" # ...Pema who?
        .then => @send @pemaInA, "Pema in A" # Hello Pema in A
        .then => @send @nimaInA, "Nima in A" # Hello Pema in A

      it 'responds to both without conflict', ->
        @messages.should.eql [
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "Who's there?" ],
          [ '#A', 'pema', "knock knock" ],
          [ '#A', 'hubot', "Who's there?" ],
          [ '#A', 'nima', "Nima" ],
          [ '#A', 'hubot', "Nima who?" ],
          [ '#A', 'pema', "Pema" ],
          [ '#A', 'hubot', "Pema who?" ],
          [ '#A', 'pema', "Pema in A" ],
          [ '#A', 'hubot', "Hello Pema in A" ],
          [ '#A', 'nima', "Nima in A" ],
          [ '#A', 'hubot', "Hello Nima in A" ],
        ]