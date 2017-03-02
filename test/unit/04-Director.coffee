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
Observer = require '../utils/observer'
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'
Director = require '../../src/modules/Director'
Playbook = require '../../src/Playbook'

describe '#Dialogue', ->

  # create room and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'
    @robot = @room.robot
    @observer = new Observer @room.messages
    @robot.on 'respond', (res) => @res = res # store every response sent
    @robot.on 'receive', (res) => @rec = res # store every message received
    @spy = _.mapObject Director.prototype, (val, key) ->
      sinon.spy Director.prototype, key # spy on all the class methods
    @room.user.say 'tester', 'hubot ping' # trigger first response

  afterEach ->
    _.invoke @spy, 'restore' # restore all the methods
    @room.destroy()

  describe 'constructor', ->

    context 'without options', ->

      beforeEach ->
        delete process.env.DENIED_RESPONSE # prevent interference
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot

      it 'does not throw', ->
        @director.should.not.have.threw

      it 'has object of empty whitelist users/roles/rooms arrays', ->
        @director.whitelist.should.eql users: [], roles: [], rooms: []

      it 'has object of empty blacklist users/roles/rooms arrays', ->
        @director.blacklist.should.eql users: [], roles: [], rooms: []

      it 'stores default fallback config', ->
        @director.config.deniedResponse.should.equal "Sorry, I can't do that."

    context 'with options', ->

      beforeEach ->
        delete process.env.DENIED_RESPONSE # prevent interference
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot, deniedResponse: "DENIED!"

      it 'stores passed options in config', ->
        @director.config.deniedResponse.should.equal "DENIED!"

    context 'with env vars for config', ->

      beforeEach ->
        process.env.DENIED_RESPONSE = "403 Sorry."
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot

      afterEach ->
        delete process.env.DENIED_RESPONSE

      it 'stores env vars in config', ->
        @director.config.deniedResponse.should.equal "403 Sorry."

    context 'with env vars and options', ->

      beforeEach ->
        process.env.DENIED_RESPONSE = "403 Sorry."
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot, deniedResponse: "DENIED!"

      afterEach ->
        delete process.env.DENIED_RESPONSE

      it 'stores passed options in config (overriding env vars)', ->
        @director.config.deniedResponse.should.equal "DENIED!"

  describe '.whitelistAdd', ->

      context 'with users type and array of usernames', ->

        beforeEach ->
          @director = new Director @robot
          @director.whitelistAdd 'users', ['pema', 'nima']

        it 'stores the usernames in the whitelist users array', ->
          @director.whitelist.users.should.eql ['pema', 'nima']

      context 'with users type and single username', ->

        beforeEach ->
          @director = new Director @robot
          @director.whitelistAdd 'users', 'pema'

        it 'stores the username in the whitelist users array', ->
          @director.whitelist.users.should.eql ['pema']

      context 'with users type and array of users, some existing', ->

        beforeEach ->
          @director = new Director @robot
          @director.whitelist.users = ['yeon', 'juan']
          @director.whitelistAdd 'users', ['pema', 'juan', 'nima']

        it 'adds any missing, not duplicating existing', ->
          @director.whitelist.users.should.eql ['yeon', 'juan', 'pema', 'nima']

      context 'with invalid type', ->

        beforeEach ->
          @director = new Director @robot
          try
            @director.whitelistAdd 'names', ['pema', 'juan', 'nima']

        it 'throws error when given invalid type', ->
          @spy.whitelistAdd.should.have.threw
