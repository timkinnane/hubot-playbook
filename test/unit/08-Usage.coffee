Q = require 'q'
_ = require 'underscore'
{generate} = require 'randomstring'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

{Robot, TextMessage, User} = require 'hubot'
Playbook = require '../../src/Playbook'

describe 'Playbook usage (messaging test cases)', ->

  before ->

    # helper to send messages to bot, returns promise
    @send = (user, text) =>
      deferred = Q.defer()
      msg = new TextMessage user, text, generate 12 # hash message ID
      @robot.receive msg, -> deferred.resolve() # resolve as callback
      return deferred.promise

    # same username in two rooms should be recognised as same user
    @nimaInFoo = new User 'nima', room: 'foo'
    @pemaInFoo = new User 'pema', room: 'foo'
    @nemaInBar = new User 'nima', room: 'bar'
    @pemaInFoo = new User 'pema', room: 'bar'

  beforeEach ->
    @robot = new Robot 'hubot/src/adapters', 'shell'
    @playbook = new Playbook @robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    require('../scripts/ping.coffee') @robot # run hubot through test script
    @messages = [] # store every listen and response...
    @robot.on 'receive', (res) =>
      @messages.push [res.message.room, res.message.user.name, res.message.text]
    @robot.on 'respond', (res, strings) =>
      console.log '<>><>><'
      @messages.push [res.message.room, 'hubot', strings]

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

    context 'user enters dialogue, they and another user respond to prompt', ->

      beforeEach ->
        # unmute = mute()
        @robot.hear /knock/, (res1) =>
          @dialogue = @scene.enter res1
          @dialogue.branch /.*/, (res2) =>
            @dialogue.send "#{ res2.match[0] } who?"
            @dialogue.branch /.*/, "hahaha, good one."

        @send @nimaInFoo, 'knock knock' # who's there?
        @send @pemaInFoo, 'Pema' # ignored
        @send @nimaInFoo, 'Nima' # Nima who?
        @send @nimaInFoo, 'Nima in Foo' # haha
        # .then -> unmute()

      it 'responds to first user only', ->
        console.log inspect @messages

  #   it 'responds to the first user outside the room', ->
  #
  #   it 'does not respond to other users', ->
  #
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
