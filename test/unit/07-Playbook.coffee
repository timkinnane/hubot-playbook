Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Helper = require 'hubot-test-helper'
helper = new Helper "../scripts/ping.coffee"
Playbook = require '../../src/Playbook'
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'

describe '#Playbook', ->

  beforeEach ->
    @room = helper.createRoom()
    @playbook = new Playbook @room.robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    @room.robot.on 'respond', (res) => @res = res # store every response sent
    @room.user.say 'tester', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

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
