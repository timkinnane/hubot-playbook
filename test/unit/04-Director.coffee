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

describe '#Director', ->

  # create room and initiate a response to test with
  beforeEach ->
    delete process.env.DENIED_RESPONSE # prevent interference
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

    context 'without key or options', ->

      beforeEach ->
        unmute = mute()
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot
        unmute()

      it 'does not throw', ->
        @director.should.not.have.threw

      it 'has object of empty whitelist users/roles/rooms arrays', ->
        @director.whitelist.should.eql users: [], roles: [], rooms: []

      it 'has object of empty blacklist users/roles/rooms arrays', ->
        @director.blacklist.should.eql users: [], roles: [], rooms: []

      it 'stores default fallback config', ->
        @director.config.deniedResponse.should.equal "Sorry, I can't do that."

      it 'calls keygen to create a random key', ->
        @spy.keygen.getCall(0).should.have.calledWith()

    context 'without key, with options', ->

      beforeEach ->
        unmute = mute()

        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot, deniedResponse: "DENIED!"
        unmute()

      it 'stores passed options in config', ->
        @director.config.deniedResponse.should.equal "DENIED!"

      it 'calls keygen to create a random key', ->
        @spy.keygen.getCall(0).should.have.calledWith()

      it 'stores the generated key as an attribute', ->
        @director.key.length.should.equal 12

    context 'with key and options', ->

      beforeEach ->
        unmute = mute()
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot, 'Orson Welles'
        unmute()

      it 'calls keygen with provided source', ->
        @spy.keygen.getCall(0).should.have.calledWith 'Orson Welles'

      it 'stores the slugified source key as an attribute', ->
        @director.key.should.equal 'Orson-Welles'

    context 'with env vars for config', ->

      beforeEach ->
        unmute = mute()
        process.env.DENIED_RESPONSE = "403 Sorry."
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot
        unmute()

      afterEach ->
        delete process.env.DENIED_RESPONSE

      it 'stores env vars in config', ->
        @director.config.deniedResponse.should.equal "403 Sorry."

    context 'with env vars and options', ->

      beforeEach ->
        unmute = mute()
        process.env.DENIED_RESPONSE = "403 Sorry."
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot, deniedResponse: "DENIED!"
        unmute()

      afterEach ->
        delete process.env.DENIED_RESPONSE

      it 'stores passed options in config (overriding env vars)', ->
        @director.config.deniedResponse.should.equal "DENIED!"

  describe '.keygen', ->

    beforeEach ->
      unmute = mute()
      @director = new Director @robot
      unmute()

    context 'with a source string', ->

      beforeEach ->
        @result = @director.keygen '%.test @# String!'

      it 'converts or removes unsafe characters', ->
        @result.should.equal 'test-String'

    context 'without source', ->

      beforeEach ->
        unmute = mute()
        @result = @director.keygen()
        unmute()

      it 'creates a string of 12 random characters', ->
        @result.length.should.equal 12

  describe '.whitelistAdd', ->

      context 'with users type and array of usernames', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelistAdd 'users', ['pema', 'nima']
          unmute()

        it 'stores the usernames in the whitelist users array', ->
          @director.whitelist.users.should.eql ['pema', 'nima']

      context 'with users type and single username', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelistAdd 'users', 'pema'
          unmute()

        it 'stores the username in the whitelist users array', ->
          @director.whitelist.users.should.eql ['pema']

      context 'with users type and array of users, some existing', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelist.users = ['yeon', 'juan']
          @director.whitelistAdd 'users', ['pema', 'juan', 'nima']
          unmute()

        it 'adds any missing, not duplicating existing', ->
          @director.whitelist.users.should.eql ['yeon', 'juan', 'pema', 'nima']

      context 'with invalid type', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          try
            @director.whitelistAdd 'names', ['pema', 'juan', 'nima']
          unmute()

        it 'throws error when given invalid type', ->
          @spy.whitelistAdd.should.have.threw

  describe '.whitelistRemove', ->

      context 'with users type and array of usernames', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelist.users = ['yeon', 'pema', 'juan', 'nima']
          @director.whitelistRemove 'users', ['pema', 'nima']
          mute()

        it 'removes the usernames from the whitelist users array', ->
          @director.whitelist.users.should.eql ['yeon', 'juan']

      context 'with users type and single username', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelist.users = ['yeon', 'pema', 'juan', 'nima']
          @director.whitelistRemove 'users', 'pema'
          unmute()

        it 'stores the username in the whitelist users array', ->
          @director.whitelist.users.should.eql ['yeon', 'juan', 'nima']

      context 'with users type and array of users, some not existing', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          @director.whitelist.users = ['yeon', 'juan']
          @director.whitelistRemove 'users', ['pema', 'juan', 'nima']
          unmute()

        it 'adds any missing, not duplicating existing', ->
          @director.whitelist.users.should.eql ['yeon']

      context 'with invalid type', ->

        beforeEach ->
          unmute = mute()
          @director = new Director @robot
          try
            @director.whitelistRemove 'names', ['pema', 'juan', 'nima']
          unmute()

        it 'throws error when given invalid type', ->
          @spy.whitelistRemove.should.have.threw
