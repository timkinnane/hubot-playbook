Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

{Robot, TextMessage, User} = require 'hubot'
Playbook = require '../../src/Playbook'
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'

describe '#Playbook', ->

  beforeEach ->
    @robot = new Robot 'hubot/src/adapters', 'shell'
    @playbook = new Playbook @robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    require('../scripts/ping.coffee') @robot # run hubot through basic script
    @robot.on 'respond', (res) => @res = res # store every response sent
    @room.user.say 'tester', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods

  context '.dialogue', ->

    beforeEach ->
      @dialogue = @playbook.dialogue @res

    it 'creates Dialogue instance', ->
      @dialogue.should.be.instanceof Dialogue

    it 'does not throw any errors', ->
      @spy.dialogue.should.not.have.threw

  context '.scene', ->

    beforeEach ->
      @scene = @playbook.scene()

    it 'makes a Scene :P', ->
      @scene.should.be.instanceof Scene

    it 'does not throw any errors', ->
      @spy.scene.should.not.have.threw

# describe 'Usage (general messaging test cases)', ->
#
#   # create two rooms for tesitng scene types
#   beforeEach ->
#     # @room = helper.createRoom httpd: false
#     # @fooRoom = helper.createRoom name: 'foo', httpd: false
#     # @barRoom = helper.createRoom name: 'bar', httpd: false
#     #  ^ httpd must be false to prevent port conflict with two listens
#
#   context 'scene type "user"', ->
#
#     beforeEach ->
#       unmute = mute() # hide logs from test results
#       @scene = new Scene @room.robot, 'user'
#       # @observer = new Observer @room.messages # TODO: test async messages
#       @room.robot.hear /hi/, (res) =>
#         @dialogue = @scene.enter res
#         @dialogue?.path
#           prompt: 'hi, hope we meet again'
#           branches: [
#             [ /again/, 'hi you again' ]
#           ]
#       @room.user.say 'joe', 'hi, i am joe'
#       Q.delay(10).then => @room.user.say 'jane', 'hi, i am jane'
#       Q.delay(10).then => @room.user.say 'joe', 'hi, joe again' # TODO: test using different room
#       Q.delay(10).then => @room.user.say 'jane', 'hi, jane again' # TODO: test using different room
#
#       unmute()
#
#     it 'responds to user in the room', ->
#       console.log @room.messages
#       # @room.messages.should.eql [
#       #   [ 'joe', 'hi, i am joe' ]
#       #   [ 'hubot', 'hi, hope we meet again' ]
#       #   [ 'jane', 'hi, i am jane' ]
#       #   [ 'joe', 'hi, joe again' ]
#       #   [ 'hubot', 'hi you again' ]
#       #   [ 'jane', 'hi, jane again' ]
#       # ]
#
#   #
#   #   it 'responds to the first user outside the room', ->
#   #
#   #   it 'does not respond to other users', ->
#   #
#   # context 'scene type "room"', ->
#   #
#   #   beforeEach ->
#   #
#   #   it 'responds to the first user in the room', ->
#   #
#   #   it 'responds to other users in the room', ->
#   #
#   #   it 'does not respond in other rooms', ->
#   #
#   # context 'scene type "userRoom"', ->
#   #
#   #   it 'responds to the first user in the room', ->
#   #
#   #   it 'does not respond to the first user in other rooms', ->
#   #
#   #   it 'does not respond in other rooms', ->
#
#
#   # TODO: message tests dialogue choices allow matching from
#   # - user scene = user in any room
#   # - room scene = anyone in room, not other rooms
#   # - userRoom scene = user in room, not other rooms
#   # - Use examples from hubot-conversation and strato index
#   # - engage user in room, should ignore other users
#   # - engage two separate users in room, run parallel dialogues without conflict
#
# # TODO: Add test that user scene dialogue will only "respond", group will "hear"
