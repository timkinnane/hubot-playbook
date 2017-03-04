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

      it 'has object of empty whitelist usernames, rooms arrays', ->
        @director.whitelist.should.eql usernames: [], rooms: []

      it 'has object of empty blacklist usernames/rooms arrays', ->
        @director.blacklist.should.eql usernames: [], rooms: []

      it 'stores default fallback config', ->
        @director.config.deniedResponse.should.equal "Sorry, I can't do that."

      it 'calls keygen to create a random key', ->
        @spy.keygen.getCall(0).should.have.calledWith()

    context 'without key or options, with env var for black/whitelists', ->

      beforeEach ->
        unmute = mute()
        process.env.WHITELIST_USERS = 'Emmanuel'
        process.env.WHITELIST_ROOMS = 'Capital'
        process.env.BLACKLIST_USERS = 'Winston,Julia,Syme'
        process.env.BLACKLIST_ROOMS = 'Labour'
        namespace = Director: require "../../src/modules/Director"
        @director = new namespace.Director @robot
        unmute()

      afterEach ->
        delete process.env.WHITELIST_USERS
        delete process.env.WHITELIST_ROOMS
        delete process.env.BLACKLIST_USERS
        delete process.env.BLACKLIST_ROOMS

      it 'stores the whitelisted usernames from the env var', ->
        @director.whitelist.usernames.should.eql ['Emmanuel']

      it 'stores the whitelisted rooms in from the env var', ->
        @director.whitelist.rooms.should.eql ['Capital']

      it 'stores the blacklisted usernames in from the env var', ->
        @director.blacklist.usernames.should.eql ['Winston','Julia','Syme']

      it 'stores the blacklisted rooms in from the env var', ->
        @director.blacklist.rooms.should.eql ['Labour']

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

  describe '.blacklistAdd', ->

    context 'with users type and array of usernames', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        @director.blacklistAdd 'users', ['pema', 'nima']
        unmute()

      it 'stores the usernames in the blacklist users array', ->
        @director.blacklist.users.should.eql ['pema', 'nima']

    context 'with users type and single username', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        @director.blacklistAdd 'users', 'pema'
        unmute()

      it 'stores the username in the blacklist users array', ->
        @director.blacklist.users.should.eql ['pema']

    context 'with invalid type', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        try
          @director.blacklistAdd 'names', ['pema', 'juan', 'nima']
        unmute()

      it 'throws error when given invalid type', ->
        @spy.blacklistAdd.should.have.threw

  describe '.blacklistRemove', ->

    context 'with users type and array of usernames', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        @director.blacklist.users = ['yeon', 'pema', 'juan', 'nima']
        @director.blacklistRemove 'users', ['pema', 'nima']
        mute()

      it 'removes the usernames from the blacklist users array', ->
        @director.blacklist.users.should.eql ['yeon', 'juan']

    context 'with users type and single username', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        @director.blacklist.users = ['yeon', 'pema', 'juan', 'nima']
        @director.blacklistRemove 'users', 'pema'
        unmute()

      it 'stores the username in the blacklist users array', ->
        @director.blacklist.users.should.eql ['yeon', 'juan', 'nima']

    context 'with invalid type', ->

      beforeEach ->
        unmute = mute()
        @director = new Director @robot
        try
          @director.blacklistRemove 'names', ['pema', 'juan', 'nima']
        unmute()

      it 'throws error when given invalid type', ->
        @spy.blacklistRemove.should.have.threw

  describe '.directScene', ->

    beforeEach ->
      @director = new Director @robot
      @scene = new Scene @robot
      @director.directScene @scene

    context 'when scene enter manually called - user not allowed', ->

      beforeEach ->
        @director.blacklistAdd 'users', 'tester'
        @dialogue = @scene.enter @res

      it 'calls canEnter, returning false', ->
        @spy.canEnter.getCall(0).returnValue.should.be.false

      it 'preempts the .enter method, returning false instead', ->
        @dialogue.should.be.false

    context 'when scene enter manually called - user allowed', ->

      beforeEach ->
        @director.whitelistAdd 'users', 'tester'
        @dialogue = @scene.enter @res

      it 'calls canEnter, returning false', ->
        @spy.canEnter.getCall(0).returnValue.should.be.false

      it 'allowed the .enter method, returning a Dialogue object', ->
        @dialogue.should.be.instanceof Dialogue

    context 'when matched listeners - user not allowed', ->

      # TODO: test middleware attached

    context 'when matched listeners - user allowed', ->

      # TODO: test middleware attached

  describe '.canEnter', ->

    context 'blacklisted user, without authMethod', ->

      beforeEach ->
        @result = @scene.enter @res

      it 'calls .canEnter to check if origin of response can access', ->
        @spy.canEnter.getCall(0).should.have.calledWith @scene, @res

      it 'preempts (hooks) the enter function result to return false', ->
        @result.should.be.false

    # TODO: all the below

    context 'blacklisted room, without authMethod', ->

    context 'blacklisted user, with authMethod', ->

    context 'blacklisted room, with authMethod', ->

    context 'whitelisted user, without authMethod', ->

    context 'whitelisted room, without authMethod', ->

    context 'whitelisted user, with authMethod', ->

    context 'whitelisted room, with authMethod', ->

    context 'function as authMethod', ->

    context 'adapter method name as authMethod', ->
