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

    @playbook = new Playbook @robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    @messages = [] # reset store of receits and responses

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @robot.shutdown()

  context 'knock knock test - user scene', ->

    beforeEach ->
      unmute = mute()
      @scene = @playbook.scene 'user'
      @robot.hear /knock/, (res) =>
        @dialogue = @scene.enter res
        @dialogue.send "Who's there?"
        @dialogue.branch /.*/, (res) =>
          @dialogue.send "#{ res.match[0] } who?"
          @dialogue.branch /.*/, "Hello #{ res.match[0] }"
      unmute()

    afterEach ->
      unmute = mute()
      @scene.exitAll()
      unmute()

    context 'Nima begins in A, continues in B, Pema tries in both', ->

      beforeEach ->
        unmute = mute()
        @send @nimaInA, 'knock knock' # ...Who's there?
        .then => @send @pemaInA, 'Pema in A' # ...ignored
        .then => @send @nimaInB, 'Nima in B' # ...Nima in B who?
        .then => @send @pemaInB, 'Pema in B' # ...ignored
        .then -> unmute()

      it 'responds to Nima in both, ignores Pema in both', ->
        @messages.should.eql [
          [ '#A', 'nima', 'knock knock' ],
          [ '#A', 'hubot', 'Who\'s there?' ],
          [ '#A', 'pema', 'Pema in A' ],
          [ '#B', 'nima', 'Nima in B' ],
          [ '#A', 'hubot', 'Nima in B who?' ],
          [ '#B', 'pema', 'Pema in B' ]
        ]

  context 'scene type "room"', ->

    beforeEach ->
      @scene = @playbook.scene 'room'

    afterEach ->
      unmute = mute()
      @scene.exitAll()
      unmute()

    context 'Nima begins in A, continues in B, Pema responds in A', ->

      beforeEach ->
        unmute = mute()
        @send @nimaInA, 'knock knock' # ...Who's there?
        .then => @send @pemaInA, 'Pema' # ...Pema who?
        .then => @send @pemaInB, 'Pema in B' # ...Pema who?
        .then => @send @nimaInB, 'No it\'s Nima' # No it's Nima who?
        .then => @send @pemaInB, 'Hey!?' # ...ignored
        .then -> unmute()

      it 'responds to Nima or Pema in A, ignores in B', ->
        @messages.should.eql [
          [ '#A', 'nima', 'knock knock' ],
          [ '#A', 'hubot', 'Who\'s there?' ],
          [ '#A', 'pema', 'Pema' ],
          [ '#A', 'hubot', 'Pema who?' ],
          [ '#B', 'pema', 'Pema in B' ],
          [ '#A', 'nima', 'No it\'s Nima' ],
          [ '#A', 'hubot', 'No it\'s Nima who?' ],
          [ '#A', 'pema', 'Hey!?' ]
        ]
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
