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
    @room = helper.createRoom name: 'testing'
    @robot = @room.robot
    @spy = _.mapObject Playbook.prototype, (val, key) ->
      sinon.spy Playbook.prototype, key # spy on all the class methods
    @robot.on 'respond', (res) => @res = res # store every response sent
    @room.user.say 'tester', 'hubot ping' # create first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  describe 'constructor', ->

    beforeEach ->
      namespace = Playbook: require "../../src/Playbook"
      @constructor = sinon.spy namespace, 'Playbook'
      @playbook = new namespace.Playbook @robot

    it 'does not throw', ->
      @constructor.should.not.have.threw

    it 'has an empty array of scenes', ->
      @playbook.scenes.should.eql []

    it 'has an empty array of dialogues', ->
      @playbook.dialogues.should.eql []

  describe '.scene', ->

    beforeEach ->
      @playbook = new Playbook @robot
      @scene = @playbook.scene()

    it 'makes a Scene :P', ->
      @scene.should.be.instanceof Scene

    it 'does not throw any errors', ->
      @spy.scene.should.not.have.threw

  describe '.enterScene', ->

    context 'with type, without options args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.enterScene 'room', @res
        unmute()

      it 'makes a Scene (stored, not returned)', ->
        @playbook.scenes[0].should.be.instanceof Scene

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'returns a dialogue', ->
        @dialogue.should.be.instanceof Dialogue

      it 'enters scene, engaging room', ->
        @playbook.scenes[0].engaged['testing'].should.eql @dialogue

    context 'with type and options args', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.enterScene 'room', @res, reply: false
        unmute()

      it 'used the given room type', ->
        @playbook.scenes[0].type.should.equal 'room'

      it 'used the options argument', ->
        @dialogue.config.reply = false

    context 'without type or args (other than response)', ->

      beforeEach ->
        unmute = mute()
        @playbook = new Playbook @robot
        @dialogue = @playbook.enterScene @res
        unmute()

      it 'makes scene with default user type', ->
        @playbook.scenes[0].should.be.instanceof Scene
        @playbook.scenes[0].type.should.equal 'user'

  describe '.introScene', ->

    beforeEach (done) ->
      unmute = mute()
      @playbook = new Playbook @robot
      @cbSpy = sinon.spy()
      cbSpy = @cbSpy
      @robot.hear /.*/, (@res) => null # get any response for comparison
      @scene = @playbook.introScene 'hear', /test/, 'user', (res) ->
        cbSpy @, res
        done()
      @room.user.say 'tester', 'test'
      return

    it 'creates Scene instance', ->
      @scene.should.be.instanceof Scene

    it 'called the enter callback from listener', ->
      @cbSpy.should.have.calledOnce

    it 'creates Dialogue instance, replaces "this" in callback', ->
      @cbSpy.args[0][0].should.be.instanceof Dialogue

    it 'passed along response object from listener', ->
      @cbSpy.args[0][1].should.eql @res

  describe '.dialogue', ->

    beforeEach ->
      @playbook = new Playbook @robot
      @dialogue = @playbook.dialogue @res

    it 'creates Dialogue instance', ->
      @dialogue.should.be.instanceof Dialogue

    it 'does not throw any errors', ->
      @spy.dialogue.should.not.have.threw

  describe '.shutdown', ->

    beforeEach ->
      unmute = mute()
      @playbook = new Playbook @robot
      @dialogue = @playbook.dialogue @res
      @scene = @playbook.scene()
      @endSpy = sinon.spy @dialogue, 'end'
      @exitSpy = sinon.spy @scene, 'exitAll'
      @playbook.shutdown()
      unmute()

    it 'calls .exitAll on scenes', ->
      @exitSpy.should.have.calledOnce

    it 'calls .end on dialogues', ->
      @endSpy.should.have.calledOnce
