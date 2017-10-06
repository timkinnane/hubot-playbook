sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
_ = require 'lodash'
co = require 'co'
pretend = require 'hubot-pretend'
Dialogue = require '../../src/modules/dialogue'
Scene = require '../../src/modules/scene'
Director = require '../../src/modules/director'

describe 'Director', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'
    @tester = pretend.user 'tester', id:'tester', room: 'testing'

    Object.getOwnPropertyNames(Director.prototype).map (key) ->
      sinon.spy Director.prototype, key

    # generate first response for starting dialogues
    pretend.robot.hear /test/, -> # listen to tests
    pretend.user('tester').send 'test'
    .then => @res = pretend.lastListen()

  afterEach ->
    pretend.shutdown()

    Object.getOwnPropertyNames(Director.prototype).map (key) ->
      Director.prototype[key].restore()

  describe 'constructor', ->

    context 'without optional args', ->

      beforeEach ->
        @director = new Director pretend.robot

      it 'has empty array names', ->
        @director.names.should.eql []

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

    context 'with env var for config', ->

      beforeEach ->
        process.env.DENIED_REPLY = "403 Sorry."
        @director = new Director pretend.robot

      afterEach ->
        delete process.env.DENIED_REPLY

      it 'has default config with env inherited', ->
        @director.config.should.eql
          type: 'whitelist'
          scope: 'username'
          deniedReply: "403 Sorry."

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
          @director.names.should.eql ['Winston', 'Julia', 'Syme']

      context 'blacklist type, room scope', ->

        beforeEach ->
          @director = new Director pretend.robot,
            type: 'blacklist'
            scope: 'room'

        it 'stores the blacklisted rooms from env', ->
          @director.names.should.eql ['Labour']

    context 'with invalid option for type', ->

      beforeEach ->
        try @director = new Director pretend.robot,
          type: 'pinklist'

      it 'should throw error', ->
        Director.prototype.constructor.should.throw

    context 'with invalid option for scope', ->

      beforeEach ->
        try @director = new Director pretend.robot,
          scope: 'robot'

      it 'should throw error', ->
        Director.prototype.constructor.should.throw

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
        @director.names = ['yeon', 'juan']
        @director.add ['pema', 'juan']

      it 'adds any missing, not duplicating existing', ->
        @director.names.should.eql ['yeon', 'juan', 'pema']

  describe '.remove', ->

    beforeEach ->
      @director = new Director pretend.robot
      @director.names = ['yeon', 'pema', 'juan', 'nima']

    context 'given array of names', ->

      beforeEach ->
        @director.remove ['pema', 'nima']

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

      context 'no list', ->

        it 'returns false', ->
          director = new Director pretend.robot
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.false

      context 'has list, username on list', ->

        it 'returns true', ->
          director = new Director pretend.robot
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.true

      context 'has list, username not on list', ->

        it 'returns false', ->
          director = new Director pretend.robot
          director.names = ['nobody']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.false

    context 'blacklist without authorise function', ->

      context 'no list', ->

        it 'returns true', ->
          director = new Director pretend.robot, type: 'blacklist'
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.true

      context 'has list, username on list', ->

        it 'returns false', ->
          director = new Director pretend.robot, type: 'blacklist'
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.false

      context 'has list, username not on list', ->

        it 'returns true', ->
          director = new Director pretend.robot, type: 'blacklist'
          director.names = ['nobody']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.true

    context 'whitelist with authorise function', ->

      context 'no list', ->

        it 'calls authorise function with username and res', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise
          res = pretend.response 'tester', 'test'
          director.isAllowed res
          authorise.should.have.calledWith 'tester', res

        it 'returns value of authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise
          director.isAllowed pretend.response 'tester', 'test'
          .should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        it 'returns true', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.true

        it 'does not call authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          authorise.should.not.have.been.calledOnce

      context 'has list, username not on list', ->

        it 'returns value of authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise
          director.names = ['nobody']
          director.isAllowed pretend.response 'tester', 'test'
          .should.equal 'AUTHORISE'

    context 'blacklist with authorise function', ->

      context 'no list', ->

        it 'calls authorise function with username and res', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise, type: 'blacklist'
          res = pretend.response 'tester', 'test'
          director.isAllowed res
          authorise.should.have.calledWith 'tester', res

        it 'returns value of authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise, type: 'blacklist'
          director.isAllowed pretend.response 'tester', 'test'
          .should.equal 'AUTHORISE'

      context 'has list, username on list', ->

        it 'returns false', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise, type: 'blacklist'
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          .should.be.false

        it 'does not call authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise, type: 'blacklist'
          director.names = ['tester']
          director.isAllowed pretend.response 'tester', 'test'
          authorise.should.not.have.been.calledOnce

      context 'has list, username not on list', ->

        it 'returns value of authorise function', ->
          authorise = sinon.spy -> 'AUTHORISE'
          director = new Director pretend.robot, authorise, type: 'blacklist'
          director.names = ['nobody']
          director.isAllowed pretend.response 'tester', 'test'
          .should.equal 'AUTHORISE'

    context 'room scope, blacklist room', ->

      it 'returns false', ->
        director = new Director pretend.robot, type: 'blacklist', scope: 'room'
        director.names = ['testing']
        director.isAllowed pretend.response 'tester', 'test', 'testing'
        .should.be.false

    context 'room scope, whitelist room', ->

      it 'returns true', ->
        director = new Director pretend.robot, type: 'whitelist', scope: 'room'
        director.names = ['testing']
        director.isAllowed pretend.response 'tester', 'test', 'testing'
        .should.be.true

  describe '.process', ->

    it 'calls .isAllowed to determine if user is allowed or denied', ->
      director = new Director pretend.robot
      scene = new Scene pretend.robot
      res = pretend.response 'tester', 'testing'
      director.process res
      director.isAllowed.should.have.calledWith res

    it 'returns a promise', ->
      director = new Director pretend.robot
      scene = new Scene pretend.robot
      director.process pretend.response 'tester', 'testing'
      .then.should.be.a 'function'

    it 'resolves to .isAllowed result', -> co ->
      director = new Director pretend.robot
      scene = new Scene pretend.robot
      result = yield director.process pretend.response 'tester', 'testing'
      result.should.equal director.isAllowed.returnValues.pop()

    context 'with async auth function', ->

      it 'resolves with auth function result after finished', -> co ->
        authorise = -> new Promise (resolve, reject) ->
          done = -> resolve('AUTHORISE')
          setTimeout done, 30
        director = new Director pretend.robot, authorise
        result = yield director.process pretend.response 'tester', 'test'
        result.should.equal 'AUTHORISE'

    context 'denied with denied reply value', ->

      it 'calls response method reply with reply value', -> co ->
        director = new Director pretend.robot, deniedReply: 'DENIED'
        res = pretend.response 'tester', 'test'
        yield director.process res
        res.reply.should.have.calledWith 'DENIED'

    context 'denied without denied reply value', ->

      it 'does not call response reply method', -> co ->
        director = new Director pretend.robot
        res = pretend.response 'tester', 'test'
        yield director.process res
        res.reply.should.not.have.called

    context 'allowed user with denied reply value', ->

      it 'calls .isAllowed to determine if user is allowed or denied', -> co ->
        director = new Director pretend.robot
        director.names = ['tester']
        res = pretend.response 'tester', 'test'
        yield director.process res
        director.isAllowed.should.have.calledWith res

      it 'resolves to same value as .isAllowed', -> co ->
        director = new Director pretend.robot
        director.names = ['tester']
        result = yield director.process pretend.response 'tester', 'test'
        result.should.equal director.isAllowed.returnValues.pop()

      it 'does not send denied reply', -> co ->
        director = new Director pretend.robot
        director.names = ['tester']
        res = pretend.response 'tester', 'test'
        yield director.process res
        res.reply.should.not.have.called

  describe '.directMatch', ->

    context 'allowed user sending message matching directed match', ->

      it 'calls .process to perform access checks and reply', -> co ->
        director = new Director pretend.robot
        pretend.robot.hear /let me in/, ->
        director.directMatch /let me in/
        director.names = ['tester']
        yield pretend.user('tester').send 'let me in'
        director.process.should.have.calledOnce

      it 'triggers match callback normally', -> co ->
        director = new Director pretend.robot
        callback = sinon.spy()
        pretend.robot.hear /let me in/, callback
        director.directMatch /let me in/
        director.names = ['tester']
        yield pretend.user('tester').send 'let me in'
        callback.should.have.calledOnce

    context 'denied user sending message matching directed match', ->

      it 'calls .process to perform access checks and reply', -> co ->
        director = new Director pretend.robot
        pretend.robot.hear /let me in/, ->
        director.directMatch /let me in/
        yield pretend.user('tester').send 'let me in'
        director.process.should.have.calledOnce

      it 'prevents match callback from triggering', -> co ->
        director = new Director pretend.robot
        callback = sinon.spy()
        pretend.robot.hear /let me in/, callback
        director.directMatch /let me in/
        yield pretend.user('tester').send 'let me in'
        callback.should.not.have.called

    context 'denied user sending unmatched message', ->

      it 'does not call .process because middleware did not match', -> co ->
        director = new Director pretend.robot
        pretend.robot.hear /let me in/, ->
        director.directMatch /let me in/
        yield pretend.user('tester').send 'foo'
        director.process.should.not.have.called

  describe '.directListener', ->

    context 'with message matching directed listener id', ->

      it 'calls .process to perform access checks and reply', -> co ->
        director = new Director pretend.robot
        pretend.robot.hear /let me in/, id: 'entry-test', ->
        director.directListener 'entry-test'
        yield pretend.user('tester').send 'let me in'
        director.process.should.have.calledOnce

      it 'triggers match callback when allowed', -> co ->
        director = new Director pretend.robot
        callback = sinon.spy()
        pretend.robot.hear /let me in/, id: 'entry-test', callback
        director.directListener 'entry-test'
        director.names = ['tester']
        yield pretend.user('tester').send 'let me in'
        callback.should.have.calledOnce

      it 'prevents match callback when denied', -> co ->
        director = new Director pretend.robot
        callback = sinon.spy()
        pretend.robot.hear /let me in/, id: 'entry-test', callback
        director.directListener 'entry-test'
        yield pretend.user('tester').send 'let me in'
        callback.should.not.have.called

    context 'with unmatched message', ->

      it 'does not call .process because middleware did not match', -> co ->
        director = new Director pretend.robot
        pretend.robot.hear /let me in/, id: 'entry-test', ->
        director.directListener 'entry-test'
        yield pretend.user('tester').send 'foo'
        director.process.should.not.have.called

  describe '.directScene', ->

    beforeEach ->
      sinon.spy Scene.prototype, 'enter'
      sinon.spy Scene.prototype, 'processEnter'

    afterEach ->
      Scene.prototype.enter.restore()
      Scene.prototype.processEnter.restore()

    it 'scene enter middleware calls director .process', ->
      director = new Director pretend.robot
      scene = new Scene pretend.robot
      director.directScene scene
      res = pretend.response 'tester', 'test'
      scene.enter res # won't be alllowed without adding names
      .catch -> director.process.should.have.calledWith res

    context 'user allowed', ->

      it 'allowed scene enter, resolves with context', ->
        director = new Director pretend.robot
        scene = new Scene pretend.robot
        keys = ['response', 'participants', 'options', 'arguments', 'dialogue']
        director.directScene scene
        director.names = ['tester']
        scene.enter pretend.response 'tester', 'test'
        .then (result) -> result.should.have.all.keys keys...

    context 'user denied', ->

      it 'preempts scene enter, rejects promise', ->
        director = new Director pretend.robot
        scene = new Scene pretend.robot
        director.directScene scene
        scene.enter pretend.response 'tester', 'test'
        .then () -> throw new Error 'promise should have caught'
        .catch (err) -> err.should.be.instanceof Error

    context 'with multiple scenes, only one directed', ->

      it 'calls process only once for the directed scene', -> co ->
        director = new Director pretend.robot
        sceneA = new Scene pretend.robot
        sceneB = new Scene pretend.robot
        director.directScene sceneA
        resA = pretend.response 'tester', 'let me in A'
        resB = pretend.response 'tester', 'let me in A'
        try
          yield sceneA.enter resA
          yield sceneB.enter resB
        director.process.should.have.calledOnce
        director.process.should.have.calledWithExactly resA

    # TODO: Fix hack below. Because send middleware resolves before scene enter
    # middleware, simply yielding on send will not allow asserting on the
    # outcome of the enter middleware. Need to refactor pretend with updated
    # nubot async features that use nextTick approach to ensure middleware only
    # resolves when everything final

    context 'allowed user sends message matching scene listener', ->

      it 'allows scene to process entry', (done) ->
        director = new Director pretend.robot
        scene = new Scene pretend.robot
        director.directScene scene
        director.names = ['tester']
        callback = sinon.spy()
        scene.hear /let me in/, callback
        pretend.user('tester').send 'let me in'
        setTimeout () ->
          scene.processEnter.should.have.calledOnce
          callback.should.have.calledOnce
          done()
        , 35

    context 'denied user sends message matching scene listener', ->

      it 'prevents the scene from processing entry', (done) ->
        director = new Director pretend.robot
        scene = new Scene pretend.robot
        director.directScene scene
        callback = sinon.spy()
        scene.hear /let me in/, callback
        pretend.user('tester').send 'let me in'
        setTimeout () ->
          scene.processEnter.should.not.have.called
          callback.should.not.have.called
          done()
        , 35
