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

describe 'Playbook usage (messaging test cases)', ->

  before ->
    # helper to send messages to bot, returns promise
    @send = (user, text) =>
      deferred = Q.defer()
      msg = new TextMessage user, text, generate 6 # random id
      @robot.receive msg, -> deferred.resolve() # resolve as callback
      return deferred.promise
    # same username in two rooms should be recognised as same user
    @nimaInFoo = new User 1,
      name: 'nima'
      room: '#foo'
    @pemaInFoo = new User 2,
      name: 'pema'
      room: '#foo'
    @nimaInBar = new User 1,
      name: 'nima'
      room: '#bar'
    @pemaInBar = new User 2,
      name: 'pema'
      room: '#bar'

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

    @playbook = new Playbook @robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    @messages = [] # reset store of receits and responses

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @robot.shutdown()

  context 'scene type "user"', ->

    beforeEach ->
      @scene = @playbook.scene 'user'

    afterEach ->
      unmute = mute()
      @scene.exitAll()
      unmute()

    context 'enter dialogue and another user responds to prompt', ->

      beforeEach ->
        unmute = mute()
        @robot.hear /knock/, (res) =>
          @dialogue = @scene.enter res
          @dialogue.send "Who's there?"
          @dialogue.branch /.*/, (res) =>
            @dialogue.send "#{ res.match[0] } who?"
            @dialogue.branch /.*/, "hahaha, good one."

        @send @nimaInFoo, 'knock knock' # who's there?
        .then => @send @pemaInFoo, 'Pema' # ignored
        .then => @send @nimaInFoo, 'Nima' # Nima who?
        .then => @send @nimaInFoo, 'Nima in Foo' # haha
        .then -> unmute()

      it 'responds to first user only', ->
        @messages.should.eql [
          [ '#foo', 'nima', 'knock knock' ],
          [ '#foo', 'hubot', 'Who\'s there?' ],
          [ '#foo', 'pema', 'Pema' ],
          [ '#foo', 'nima', 'Nima' ],
          [ '#foo', 'hubot', 'Nima who?' ],
          [ '#foo', 'nima', 'Nima in Foo' ],
          [ '#foo', 'hubot', 'hahaha, good one.' ]
        ]

    context 'enter dialogue and continue in another room', ->

      beforeEach ->
        unmute = mute()
        @robot.hear /knock/, (res) =>
          @dialogue = @scene.enter res
          @dialogue.send "Who's there?"
          @dialogue.branch /.*/, (res) =>
            @dialogue.send "Hi #{ res.match[0] }"

        @send @nimaInFoo, 'knock knock' # who's there?
        .then => @send @pemaInFoo, 'Pema in Foo' # ignored
        .then => @send @nimaInBar, 'Nima in Bar' # Nima who? (in other room)
        .then => @send @pemaInBar, 'Pema in Bar' # ignored
        .then -> unmute()

      it 'responds to the first user only', ->
        @messages.should.eql [
          [ '#foo', 'nima', 'knock knock' ],
          [ '#foo', 'hubot', 'Who\'s there?' ],
          [ '#foo', 'pema', 'Pema in Foo' ],
          [ '#bar', 'nima', 'Nima in Bar' ],
          [ '#foo', 'hubot', 'Hi Nima in Bar' ],
          [ '#bar', 'pema', 'Pema in Bar' ]
        ]


  # context 'scene type "room"', ->
  #
  #   beforeEach ->
  #
  #   it 'responds to the first user in the room', ->
  #
  #   it 'responds to other users in the room', ->
  #
  #   it 'does not respond in other rooms', ->
  #
  # context 'scene type "userRoom"', ->
  #
  #   it 'responds to the first user in the room', ->
  #
  #   it 'does not respond to the first user in other rooms', ->
  #
  #   it 'does not respond in other rooms', ->

  # TODO: message tests dialogue choices allow matching from
  # - user scene = user in any room
  # - room scene = anyone in room, not other rooms
  # - userRoom scene = user in room, not other rooms
  # - Use examples from hubot-conversation and strato index
  # - engage user in room, should ignore other users
  # - engage two separate users in room, run parallel dialogues without conflict

# TODO: Add test that user scene dialogue will only "respond", group will "hear"
