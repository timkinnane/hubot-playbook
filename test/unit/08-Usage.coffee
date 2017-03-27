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
# TODO: Replace ropey robot sends with better hubot-test-helper for multi rooms

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
    @robot.on 'respond', (res, strings, method) =>
      msg = res.message if res.message instanceof TextMessage and strings?
      txt = strings[0]
      txt = "@#{ msg.user.name } #{ txt }" if method is 'reply'
      @messages.push [ msg.room, 'hubot', txt ] if msg?
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
      @playbook.sceneHear /knock/, 'room', sendReplies: false, ->
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
      @playbook.sceneHear /knock/, 'direct', sendReplies: true, ->
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
          [ '#A', 'hubot', "@nima Who's there?" ],
          [ '#A', 'pema', "knock knock" ],
          [ '#A', 'hubot', "@pema Who's there?" ],
          [ '#A', 'nima', "Nima" ],
          [ '#A', 'hubot', "@nima Nima who?" ],
          [ '#A', 'pema', "Pema" ],
          [ '#A', 'hubot', "@pema Pema who?" ],
          [ '#A', 'pema', "Pema in A" ],
          [ '#A', 'hubot', "@pema Hello Pema in A" ],
          [ '#A', 'nima', "Nima in A" ],
          [ '#A', 'hubot', "@nima Hello Nima in A" ]
        ]

  context 'knock and enter test - directed scene', ->

    beforeEach ->
      @scene = @playbook.sceneHear /knock/, sendReplies: true, ->
        @send "You may enter!"

    context 'Nima is whitelisted user, both try to enter', ->

      beforeEach ->
        @playbook.director deniedReply: "Sorry, Nima's only."
          .add 'nima'
          .directScene @scene
        @send @pemaInA, 'knock knock'
        .then => @send @nimaInA, 'knock knock'

      it 'answers to Nima only, otherwise default response', ->
        @messages.should.eql [
          [ '#A', 'pema', "knock knock" ],
          [ '#A', 'hubot', "@pema Sorry, Nima's only." ],
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "@nima You may enter!" ]
        ]

    context 'Nima is blacklisted user, both try to enter', ->

      beforeEach ->
        @playbook.director
          type: 'blacklist'
          deniedReply: "Sorry, no Nima's."
        .add 'nima'
        .directScene @scene
        @send @pemaInA, 'knock knock'
        .then => @send @nimaInA, 'knock knock'

      it 'answers to Nima only, otherwise default response', ->
        @messages.should.eql [
          [ '#A', 'pema', "knock knock" ],
          [ '#A', 'hubot', "@pema You may enter!" ],
          [ '#A', 'nima', "knock knock" ],
          [ '#A', 'hubot', "@nima Sorry, no Nima's." ]
        ]

    #TODO: Fix this test - isn't responding to unallowed room
    # context 'Room #A is whitelisted, nima and pema try to enter in both', ->
    #
    #   beforeEach ->
    #     @playbook.director
    #       scope: 'room'
    #       deniedReply: "Sorry, #A users only."
    #     .add '#A'
    #     .directScene @scene
    #     @send @pemaInA, 'knock knock'
    #     .then => @send @nimaInA, 'knock knock'
    #     .then => @send @pemaInB, 'knock knock'
    #     .then => @send @nimaInB, 'knock knock'
    #
    #   it 'answers to room #A only, otherwise default response', ->
    #     console.log @messages
    #     @messages.should.eql [
    #       [ '#A', 'pema', "knock knock" ],
    #       [ '#A', 'hubot', "@pema You may enter!" ],
    #       [ '#A', 'nima', "knock knock" ],
    #       [ '#A', 'hubot', "@nima You may enter!" ],
    #       [ '#B', 'pema', "knock knock" ],
    #       [ '#B', 'hubot', "@pema Sorry, #A users only." ],
    #       [ '#B', 'nima', "knock knock" ],
    #       [ '#B', 'hubot', "@nima Sorry, #A users only." ],
    #     ]
