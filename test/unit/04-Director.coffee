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
Dialogue = require '../../src/modules/Dialogue'
Scene = require '../../src/modules/Scene'
Director = require '../../src/modules/Director'
Playbook = require '../../src/Playbook'
Helpers = require '../../src/modules/Helpers'

matchAny = new RegExp /.*/

describe '#Director', ->

  # create room and initiate a response to test with
  beforeEach ->
    @room = helper.createRoom name: 'testing'

    # store and log all responses sent and messages received
    @robot = @room.robot
    @robot.on 'receive', (@rec,txt) => @robot.logger.debug "Bot receives: " +txt
    @robot.on 'respond', (@res,txt) => @robot.logger.debug "Bot responds: " +txt
    @robot.logger.info = @robot.logger.debug = -> # silence

    # spy on all the class and helper methods
    _.map _.keys(Director.prototype), (key) -> sinon.spy Director.prototype, key
    _.map _.keys(Helpers), (key) -> sinon.spy Helpers, key

    # trigger first response
    @room.user.say 'tester', 'hubot ping'

  afterEach ->
    _.map _.keys(Director.prototype), (key) -> Director.prototype[key].restore()
    _.map _.keys(Helpers), (key) -> Helpers[key].restore()
    @room.destroy()

  describe 'constructor', ->

    context 'without env vars or optional args', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        @director = new namespace.Director @robot

      it 'does not throw', ->
        @constructor.should.not.have.threw

      it 'has empty array names', ->
        @director.names.should.eql []

      it 'has default config', ->
        @director.config.should.eql
          type: 'whitelist'
          scope: 'username'
          deniedReply: "Sorry, I can't do that."

      it 'creates an id with director scope', ->
        Helpers.keygen.should.have.calledWith 'director'

      it 'stores the generated key as an attribute', ->
        Helpers.keygen.returnValues[0].should.equal @director.id

    context 'with authorise function', ->

      beforeEach ->
        @authorise = -> null
        @director = new Director @robot, @authorise

      it 'stores the given function as its authorise method', ->
        @director.authorise = @authorise

    context 'with options (denied reply and key string)', ->

      beforeEach ->
        @director = new Director @robot,
          deniedReply: "DENIED!"
          key: 'Orson Welles'

      it 'stores passed options in config', ->
        @director.config.deniedReply.should.equal "DENIED!"

      it 'creates an id from director scope and key', ->
        Helpers.keygen.should.have.calledWith 'director', 'Orson Welles'

      it 'stores generated id as its id', ->
        @director.id.should.equal Helpers.keygen.returnValues.pop()

    context 'with env var for names', ->

      beforeEach ->
        process.env.WHITELIST_USERNAMES = 'Emmanuel'
        process.env.WHITELIST_ROOMS = 'Capital'
        process.env.BLACKLIST_USERNAMES = 'Winston,Julia,Syme'
        process.env.BLACKLIST_ROOMS = 'Labour'

      afterEach ->
        delete process.env.WHITELIST_USERNAMES
        delete process.env.WHITELIST_ROOMS
        delete process.env.BLACKLIST_USERNAMES
        delete process.env.BLACKLIST_ROOMS

      context 'whitelist type, username scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'whitelist'
            scope: 'username'

        it 'stores the whitelisted usernames from env', ->
          @director.names.should.eql ['Emmanuel']

      context 'whitelist type, room scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'whitelist'
            scope: 'room'

        it 'stores the whitelisted rooms from env', ->
          @director.names.should.eql ['Capital']

      context 'blacklist type, username scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'blacklist'
            scope: 'username'

        it 'stores the blacklisted usernames from env', ->
          @director.names.should.eql ['Winston','Julia','Syme']

      context 'blacklist type, room scope', ->

        beforeEach ->
          @director = new Director @robot,
            type: 'blacklist'
            scope: 'room'

        it 'stores the blacklisted rooms from env', ->
          @director.names.should.eql ['Labour']

    context 'with env var for reply', ->

      beforeEach ->
        process.env.DENIED_REPLY = "403 Sorry."
        @director = new Director @robot

      afterEach ->
        delete process.env.DENIED_REPLY

      it 'stores env vars in config', ->
        @director.config.deniedReply.should.equal "403 Sorry."

    context 'with env vars and args for reply', ->

      beforeEach ->
        process.env.DENIED_REPLY = "403 Sorry."
        @director = new Director @robot, deniedReply: "DENIED!"

      afterEach ->
        delete process.env.DENIED_REPLY

      it 'stores passed options in config (overriding env vars)', ->
        @director.config.deniedReply.should.equal "DENIED!"

    context 'with invalid option for type', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        try @director = new namespace.Director @robot,
          type: 'pinklist'

      it 'should throw error', ->
        @constructor.should.have.threw

    context 'with invalid option for scope', ->

      beforeEach ->
        namespace = Director: require "../../src/modules/Director"
        @constructor = sinon.spy namespace, 'Director'
        try @director = new namespace.Director @robot,
          scope: 'robot'

      it 'should throw error', ->
        @constructor.should.have.threw

    context 'without key, with authorise function and options', ->

      beforeEach ->
        @authorise = -> null
        @director = new Director @robot, @authorise,
          scope: 'room'

      it 'uses options', ->
        @director.config.scope.should.equal 'room'

      it 'uses authorise function', ->
        @director.authorise.should.eql @authorise

  describe '.add', ->

    beforeEach ->
      @director = new Director @robot

    context 'given array of names', ->

      beforeEach ->
        @director.add ['pema', 'nima']

      it 'stores them in the names array', ->
        @director.names.should.eql ['pema', 'nima']

    context 'given single name', ->

      beforeEach ->
        @director.add 'pema'

      it 'stores it in the names array', ->
        @director.names.should.eql ['pema']

    context 'given array of names, some existing', ->

      beforeEach ->
        @director.names = ['yeon','juan']
        @director.add ['pema', 'juan']

      it 'adds any missing, not duplicating existing', ->
        @director.names.should.eql ['yeon', 'juan', 'pema']

  describe '.remove', ->

    beforeEach ->
      @director = new Director @robot
      @director.names = ['yeon', 'pema', 'juan', 'nima']

    context 'given array of names', ->

      beforeEach ->
        @director.remove ['pema','nima']

      it 'removes them from the names array', ->
        @director.names.should.eql ['yeon', 'juan']

    context 'with single name', ->

      beforeEach ->
        @director.remove 'pema'

      it 'removes it from the names array', ->
        @director.names.should.eql ['yeon', 'juan', 'nima']

    context 'with array names, some not existing', ->

      beforeEach ->
        @director.remove ['frank', 'pema', 'juan', 'nima']

      it 'removes any missing, ignoring others', ->
        @director.names.should.eql ['yeon']

  describe '.isAllowed', ->

    context 'whitelist without authorise function', ->

      beforeEach ->
        @director = new Director @robot

      context 'no list', ->

        beforeEach ->
          @result = @director.isAllowed @res

        it 'returns false', ->
          @result.should.be.false

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.isAllowed @res

        it 'returns true', ->
          @result.should.be.true

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.isAllowed @res

        it 'returns false', ->
          @result.should.be.false

    context 'blacklist without authorise function', ->

      beforeEach ->
        @director = new Director @robot,
          type: 'blacklist'

      context 'no list', ->

        beforeEach ->
          @result = @director.isAllowed @res

        it 'returns true', ->
          @result.should.be.true

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.isAllowed @res

        it 'returns false', ->
          @result.should.be.false

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.isAllowed @res

        it 'returns true', ->
          @result.should.be.true

    context 'whitelist with authorise function', ->

      beforeEach ->
        @authorise = sinon.spy -> 'AUTHORISE'
        @director = new Director @robot, @authorise

      context 'no list', ->

        beforeEach ->
          @result = @director.isAllowed @res

        it 'calls authorise function with username and res', ->
          @authorise.should.have.calledWith 'tester', @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.isAllowed @res

        it 'returns true', ->
          @result.should.be.true

        it 'does not call authorise function', ->
          @authorise.should.not.have.calledOnce

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.isAllowed @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

    context 'blacklist with authorise function', ->

      beforeEach ->
        @authorise = sinon.spy -> 'AUTHORISE'
        @director = new Director @robot, @authorise,
          type: 'blacklist'

      context 'no list', ->

        beforeEach ->
          @result = @director.isAllowed @res

        it 'calls authorise function with username and res', ->
          @authorise.should.have.calledWith 'tester', @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        beforeEach ->
          @director.names = ['tester']
          @result = @director.isAllowed @res

        it 'returns false', ->
          @result.should.be.false

        it 'does not call authorise function', ->
          @authorise.should.not.have.calledOnce

      context 'has list, username not on list', ->

        beforeEach ->
          @director.names = ['nobody']
          @result = @director.isAllowed @res

        it 'returns value of authorise function', ->
          @result.should.equal 'AUTHORISE'

  describe '.process', ->

    beforeEach ->
      @reply = sinon.spy @res, 'reply'
      @director = new Director @robot
      @scene = new Scene @robot

    context 'denied user', ->

      beforeEach ->
        @result = @director.process @res

      it 'calls .isAllowed to determine if user is allowed or denied', ->
        @director.isAllowed.should.have.calledWith @res

      it 'returns the same result as .isAllowed', ->
        @result.should.equal @director.isAllowed.returnValues.pop()

    context 'denied with denied reply value', ->

      beforeEach ->
        @result = @director.process @res

      it 'calls response method reply with reply value', ->
        @reply.should.have.calledWith @director.config.deniedReply

    context 'denied without denied reply value', ->

      beforeEach ->
        @director.config.deniedReply = null
        @result = @director.process @res

      it 'does not call response reply method', ->
        @reply.should.not.have.called

    context 'allowed user', ->

      beforeEach ->
        @director.names = ['tester']
        @result = @director.process @res

      it 'calls .isAllowed to determine if user is allowed or denied', ->
        @director.isAllowed.should.have.calledWith @res

      it 'returns the same value as .isAllowed', ->
        @result.should.equal @director.isAllowed.returnValues.pop()

      it 'does not send denied reply', ->
        @reply.should.not.have.called

  describe '.directMatch', ->

    beforeEach ->
      @director = new Director @robot
      @callback = sinon.spy()
      @robot.hear /test/, @callback
      @director.directMatch /test/

    context 'allowed user sending message matching directed match', ->

      beforeEach ->
        @director.names = ['tester']
        @room.user.say 'tester', 'test'

      it 'calls .process with response to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'triggers match callback normally', ->
        @callback.should.have.calledOnce

    context 'denied user sending message matching directed match', ->

      beforeEach ->
        @room.user.say 'tester', 'test'

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'prevents match callback from triggering', ->
        @callback.should.not.have.called

    context 'denied user sending unmatched message', ->

      beforeEach ->
        @room.user.say 'tester', 'foo'

      it 'does not call .process because middleware did not match', ->
        @director.process.should.not.have.called

  describe '.directListener', ->

    beforeEach ->
      @director = new Director @robot
      @callback = sinon.spy()
      @robot.hear /test/, id: 'testyMcTest', @callback
      @director.directListener 'McTest'

    context 'allowed user sending message matching directed listener id', ->

      beforeEach ->
        @director.names = ['tester']
        @room.user.say 'tester', 'test'

      it 'calls .process with response to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'triggers match callback normally', ->
        @callback.should.have.calledOnce

    context 'denied user sending message matching directed match', ->

      beforeEach ->
        @room.user.say 'tester', 'test'

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'prevents match callback from triggering', ->
        @callback.should.not.have.called

    context 'denied user sending unmatched message', ->

      beforeEach ->
        @room.user.say 'tester', 'foo'

      it 'does not call .process because middleware did not match', ->
        @director.process.should.not.have.called

  describe '.directScene', ->

    beforeEach ->
      @director = new Director @robot
      @scene = new Scene @robot
      @enter = sinon.spy @scene, 'enter'
      @director.directScene @scene

    it 'calls .directListener to control access to scene listeners', ->
      @director.directListener.should.have.calledWith @scene.id

    context 'scene enter manually called (user allowed)', ->

      beforeEach ->
        @director.names = ['tester']
        @result = @scene.enter @res

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledWith @res

      it 'allowed the .enter method, returning a Dialogue object', ->
        @result.should.be.instanceof Dialogue

    context 'scene enter manually called (user denied)', ->

      beforeEach ->
        @result = @scene.enter @res # no list, denies all in whitelist mode

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledWith @res

      it 'preempts scene.enter, returning false instead', ->
        @result.should.be.false

    context 'allowed user sends message matching scene listener', ->

      beforeEach ->
        callback = @callback = sinon.spy()
        @scene.hear /test/, callback
        @director.names = ['tester']
        @room.user.say 'tester', 'test'

      it 'triggers the scene enter method', ->
        @enter.should.have.calledOnce

      it 'calls the scene listener callback', ->
        @callback.should.have.calledOnce

    context 'denied user sends message matching scene listener', ->

      beforeEach ->
        callback = @callback = sinon.spy()
        @scene.hear /test/, callback
        @room.user.say 'tester', 'test'

      it 'prevents the scene enter method', ->
        @enter.should.not.have.calledOnce

      it 'does not call the scene listener callback', ->
        @callback.should.not.have.calledOnce
