_ = require 'lodash'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
co = require 'co'

process.env.DENIED_REPLY = "403 Sorry." # for testing env inherited

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Dialogue, Scene, Director} = require '../../src/modules'

describe '#Director', ->

  beforeEach ->
    pretend.startup()
    @tester = pretend.user 'tester', id:'tester', room: 'testing'

    _.forIn Director.prototype, (val, key) ->
      sinon.spy Director.prototype, key if _.isFunction val

    # generate first response for starting dialogues
    @tester.send('test').then => @res = pretend.responses.incoming[0]

  afterEach ->
    pretend.shutdown()

    _.forIn Director.prototype, (val, key) ->
      Director.prototype[key].restore() if _.isFunction val

  describe 'constructor', ->

    context 'without optional args', ->

      beforeEach ->
        @director = new Director pretend.robot

      it 'has empty array names', ->
        @director.names.should.eql []

      it 'has default config with env inherited', ->
        @director.config.should.eql
          type: 'whitelist'
          scope: 'username'
          deniedReply: "403 Sorry."

    context 'with authorise function', ->

      beforeEach ->
        @authorise = -> null
        @director = new Director pretend.robot, @authorise

      it 'stores the given function as its authorise method', ->
        @director.authorise = @authorise

    context 'with options (denied reply and key string)', ->

      beforeEach ->
        @director = new Director pretend.robot,
          deniedReply: "DENIED!"
          key: 'Orson Welles'

      it 'stores passed options in config', ->
        @director.config.deniedReply.should.equal "DENIED!"

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
          @director = new Director pretend.robot,
            type: 'whitelist'
            scope: 'username'

        it 'stores the whitelisted usernames from env', ->
          @director.names.should.eql ['Emmanuel']

      context 'whitelist type, room scope', ->

        beforeEach ->
          @director = new Director pretend.robot,
            type: 'whitelist'
            scope: 'room'

        it 'stores the whitelisted rooms from env', ->
          @director.names.should.eql ['Capital']

      context 'blacklist type, username scope', ->

        beforeEach ->
          @director = new Director pretend.robot,
            type: 'blacklist'
            scope: 'username'

        it 'stores the blacklisted usernames from env', ->
          @director.names.should.eql ['Winston','Julia','Syme']

      context 'blacklist type, room scope', ->

        beforeEach ->
          @director = new Director pretend.robot,
            type: 'blacklist'
            scope: 'room'

        it 'stores the blacklisted rooms from env', ->
          @director.names.should.eql ['Labour']

    context 'with options arg for reply', ->

      beforeEach ->
        @director = new Director pretend.robot, deniedReply: "DENIED!"

      it 'stores passed options in config (overriding defaults)', ->
        @director.config.deniedReply.should.equal "DENIED!"

    context 'with invalid option for type', ->

      beforeEach ->
        try @director = new Director pretend.robot,
          type: 'pinklist'

      it 'should throw error', ->
        Director.prototype.constructor.should.have.threw

    context 'with invalid option for scope', ->

      beforeEach ->
        try @director = new Director pretend.robot,
          scope: 'robot'

      it 'should throw error', ->
        Director.prototype.constructor.should.have.threw

    context 'without key, with authorise function and options', ->

      beforeEach ->
        @authorise = -> null
        @director = new Director pretend.robot, @authorise,
          scope: 'room'

      it 'uses options', ->
        @director.config.scope.should.equal 'room'

      it 'uses authorise function', ->
        @director.authorise.should.eql @authorise

  describe '.add', ->

    beforeEach ->
      @director = new Director pretend.robot

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
      @director = new Director pretend.robot
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
        @director = new Director pretend.robot

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
        @director = new Director pretend.robot,
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
        @director = new Director pretend.robot, @authorise

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
        @director = new Director pretend.robot, @authorise,
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

    context 'room scope, blacklist room', ->

      beforeEach ->
        @director = new Director pretend.robot,
          type: 'blacklist'
          scope: 'room'
        @director.names = ['testing']
        @result = @director.isAllowed @res

      it 'returns false', ->
        @result.should.be.false

    context 'room scope, whitelist room', ->

      beforeEach ->
        @director = new Director pretend.robot,
          type: 'whitelist'
          scope: 'room'
        @director.names = ['testing']
        @result = @director.isAllowed @res

      it 'returns true', ->
        @result.should.be.true

  describe '.process', ->

    beforeEach ->
      @reply = sinon.spy @res, 'reply'
      @director = new Director pretend.robot
      @scene = new Scene pretend.robot

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
      @director = new Director pretend.robot
      @callback = sinon.spy()
      pretend.robot.hear /test/, @callback
      @director.directMatch /test/

    context 'allowed user sending message matching directed match', ->

      beforeEach ->
        @director.names = ['tester']
        @tester.send 'test'

      it 'calls .process with response to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'triggers match callback normally', ->
        @callback.should.have.calledOnce

    context 'denied user sending message matching directed match', ->

      beforeEach ->
        @tester.send 'test'

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'prevents match callback from triggering', ->
        @callback.should.not.have.called

    context 'denied user sending unmatched message', ->

      beforeEach ->
        @tester.send 'foo'

      it 'does not call .process because middleware did not match', ->
        @director.process.should.not.have.called

  describe '.directListener', ->

    beforeEach ->
      @director = new Director pretend.robot
      @callback = sinon.spy()
      pretend.robot.hear /test/, id: 'testyMcTest', @callback
      @director.directListener 'McTest'

    context 'allowed user sending message matching directed listener id', ->

      beforeEach ->
        @director.names = ['tester']
        @tester.send 'test'

      it 'calls .process with response to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'triggers match callback normally', ->
        @callback.should.have.calledOnce

    context 'denied user sending message matching directed match', ->

      beforeEach ->
        @tester.send 'test'

      it 'calls .process to perform access checks and reply', ->
        @director.process.should.have.calledOnce

      it 'prevents match callback from triggering', ->
        @callback.should.not.have.called

    context 'denied user sending unmatched message', ->

      beforeEach ->
        @tester.send 'foo'

      it 'does not call .process because middleware did not match', ->
        @director.process.should.not.have.called

  describe '.directScene', ->

    beforeEach ->
      @director = new Director pretend.robot
      @scene = new Scene pretend.robot
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
        @tester.send 'test'

      it 'triggers the scene enter method', ->
        @enter.should.have.calledOnce

      it 'calls the scene listener callback', ->
        @callback.should.have.calledOnce

    context 'denied user sends message matching scene listener', ->

      beforeEach ->
        callback = @callback = sinon.spy()
        @scene.hear /test/, callback
        @tester.send 'test'

      it 'prevents the scene enter method', ->
        @enter.should.not.have.calledOnce

      it 'does not call the scene listener callback', ->
        @callback.should.not.have.calledOnce
