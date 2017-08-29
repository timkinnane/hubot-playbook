sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
co = require 'co'
_ = require 'lodash'
pretend = require 'hubot-pretend'
Path = require '../../src/modules/path'

resMatch = (value) ->
  responseKeys = [ 'robot', 'message', 'match', 'envelope' ]
  difference = _.difference responseKeys, _.keys value
  difference.length == 0

describe 'Path', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'

  afterEach ->
    pretend.shutdown()

  describe 'constructor', ->

    context 'with branches', ->

      it 'calls .addBranch', ->
        sinon.spy Path.prototype, 'addBranch'
        path = new Path pretend.robot, [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        path.addBranch.args.should.eql [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        Path.prototype.addBranch.restore()

      it 'is not closed', ->
        path = new Path pretend.robot, [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        path.closed.should.be.false

    context 'with a single branch', ->

      it 'calls .addBranch', ->
        sinon.spy Path.prototype, 'addBranch'
        path = new Path pretend.robot, [ /ok/, 'OK, ok!' ]
        path.addBranch.args.should.eql [
          [ /ok/, 'OK, ok!' ]
        ]
        Path.prototype.addBranch.restore()

      it 'is not closed', ->
        path = new Path pretend.robot, [ /ok/, 'OK, ok!' ]
        path.closed.should.be.false

    context 'with undefined branches and options', ->

      it 'does not call .addBranch', ->
        sinon.spy Path.prototype, 'addBranch'
        path = new Path pretend.robot
        Path.prototype.addBranch.restore()

      it 'stays closed', ->
        path = new Path pretend.robot
        path.closed.should.be.true

    context 'with bad arguments for branch', ->

      beforeEach ->
        try @path = new Path pretend.robot, 'breakme.jpg'

      it 'throws', ->
        Path.constructor.should.have.threw

  describe '.addBranch', ->

    it 'creates branch object', ->
      path = new Path pretend.robot
      path.addBranch /.*/, 'foo', () ->
      path.branches[0].should.be.an 'object'

    it 'branch has valid regex', ->
      path = new Path pretend.robot
      path.addBranch /.*/, 'foo', () ->
      path.branches[0].regex.should.be.instanceof RegExp

    it 'calls getHandler with strings and callback', ->
      path = new Path pretend.robot
      callback = ->
      sinon.stub path, 'getHandler'
      path.addBranch /.*/, 'foo', callback
      path.getHandler.should.have.calledWithExactly 'foo', callback

    it 'calls getHandler with just stirngs', ->
      path = new Path pretend.robot
      sinon.stub path, 'getHandler'
      path.addBranch /.*/, ['foo', 'bar']
      path.getHandler.should.have.calledWithExactly ['foo', 'bar'], undefined

    it 'calls getHandler with just callback', ->
      path = new Path pretend.robot
      callback = ->
      sinon.stub path, 'getHandler'
      path.addBranch /.*/, callback
      path.getHandler.should.have.calledWithExactly undefined, callback

    it 'branch stores handler', ->
      path = new Path pretend.robot
      sinon.spy path, 'getHandler'
      path.addBranch /.*/, 'foo', () ->
      lasthandler = path.getHandler.returnValues[0]
      path.branches[0].handler.should.eql lasthandler

    it 'opens path', ->
      path = new Path pretend.robot
      path.addBranch /.*/, 'foo', () ->
      path.closed.should.be.false

    it 'throws with invalid regex', ->
      path = new Path pretend.robot
      try path.addBranch 'derp'
      path.addBranch.should.have.threw

    it 'throws with invalid message and/or callback', ->
      path = new Path pretend.robot
      try path.addBranch /.*/
      try path.addBranch /.*/, () ->
      try path.addBranch /.*/, 'foo', 'bar'
      path.addBranch.should.have.alwaysThrew

  describe '.getHandler', ->

    it 'returns a function', ->
      path = new Path pretend.robot
      callback = sinon.spy()
      handler = path.getHandler ['foo', 'bar'], callback
      handler.should.be.a 'function'

    context 'when handler called with response', ->

      it 'calls the callback with the response', ->
        path = new Path pretend.robot
        callback = sinon.spy()
        handler = path.getHandler ['foo', 'bar'], callback
        mockRes = reply: sinon.spy()
        handler mockRes
        callback.should.have.calledWithExactly mockRes

      it 'sends strings with dialogue if it has one', ->
        path = new Path pretend.robot
        handler = path.getHandler ['foo', 'bar']
        mockRes = reply: sinon.spy(), dialogue: send: sinon.spy()
        handler mockRes
        mockRes.dialogue.send.should.have.calledWith 'foo', 'bar'

      it 'uses response reply if there is no dialogue', ->
        path = new Path pretend.robot
        handler = path.getHandler ['foo', 'bar']
        mockRes = reply: sinon.spy()
        handler mockRes
        mockRes.reply.should.have.calledWith 'foo', 'bar'

      it 'returns promise resolving with send results', -> co ->
        path = new Path pretend.robot
        handler = path.getHandler ['foo'], () -> bar: 'baz'
        mockRes = reply: sinon.spy()
        handlerSpy = sinon.spy handler
        yield handler mockRes
        handlerSpy.returned sinon.match resMatch

      it 'returns promise also merged with callback results', -> co ->
        path = new Path pretend.robot
        handler = path.getHandler ['foo'], () -> bar: 'baz'
        mockRes = reply: sinon.spy()
        handlerSpy = sinon.spy handler
        yield handler mockRes
        handlerSpy.returned sinon.match bar: 'baz'

  describe '.match', ->

    beforeEach ->
      pretend.robot.hear /door/, -> # listen to tests
      @path = new Path pretend.robot, [
        [ /door 1/, 'you lost', -> winner: false ]
        [ /door 2/, 'you won', -> winner: true  ]
        [ /door 3/, 'try again' ]
      ]
      @match = sinon.spy()
      @mismatch = sinon.spy()
      @catch = sinon.spy()
      @path.on 'match', @match
      @path.on 'mismatch', @mismatch
      @path.on 'catch', @catch

    context 'with string matching branch regex', ->

      it 'updates match in response object', -> co =>
        yield pretend.user('sam').send 'door 1'
        yield @path.match pretend.lastListen()
        expectedMatch = 'door 1'.match @path.branches[0].regex
        pretend.lastListen().match.should.eql expectedMatch

      it 'closes the path', -> co =>
        yield pretend.user('sam').send 'door 2'
        yield @path.match pretend.lastListen()
        @path.closed.should.be.true

      it 'calls the handler for matching branch with res', -> co =>
        @path.branches[1].handler = sinon.stub()
        yield pretend.user('sam').send 'door 2'
        res = pretend.lastListen()
        yield @path.match res
        @path.branches[1].handler.should.have.calledWithExactly res

      it 'emits match with res', -> co =>
        yield pretend.user('sam').send 'door 2'
        yield @path.match pretend.lastListen()
        @match.should.have.calledWith sinon.match resMatch

    context 'with string matching multiple branches', ->

      it 'updates match in response object', -> co =>
        yield pretend.user('sam').send 'door 1 and door 2'
        yield @path.match pretend.lastListen()
        expectedMatch = 'door 1 and door 2'.match @path.branches[0].regex
        pretend.lastListen().match.should.eql expectedMatch

      it 'calls the first matching branch handler', -> co =>
        yield pretend.user('sam').send 'door 1 and door 2'
        result = yield @path.match pretend.lastListen()
        result.should.have.property 'winner', false

      it 'closes the path', -> co =>
        yield pretend.user('sam').send 'door 1 and door 2'
        yield @path.match pretend.lastListen()
        @path.closed.should.be.true

    context 'with mismatching string and no catch', ->

      it 'returns undefined', -> co =>
        yield pretend.user('sam').send 'door X'
        result = yield @path.match pretend.lastListen()
        chai.expect(result).to.be.undefined

      it 'updates match to null in response object', -> co =>
        yield pretend.user('sam').send 'door X'
        yield @path.match pretend.lastListen()
        chai.expect(pretend.lastListen().match).to.be.null

      it 'path stays open', -> co =>
        yield pretend.user('sam').send 'door X'
        yield @path.match pretend.lastListen()
        @path.closed.should.be.false

      it 'emits mismatch with res', -> co =>
        yield pretend.user('sam').send 'door X'
        yield @path.match pretend.lastListen()
        @mismatch.should.have.calledWith sinon.match resMatch

    context 'with mismatching string and catch message', ->

      it 'returns the response from send', -> co =>
        @path.configure catchMessage: 'no, wrong door'
        yield pretend.user('sam').send 'door X'
        result = yield @path.match pretend.lastListen()
        result.strings.should.eql [ 'no, wrong door' ]

      it 'emits catch with res', -> co =>
        @path.configure catchMessage: 'no, wrong door'
        yield pretend.user('sam').send 'door X'
        yield @path.match pretend.lastListen()
        @catch.should.have.calledWith sinon.match resMatch

    context 'with mismatching string and catch callback', ->

      it 'returns the result of the callback', -> co =>
        @path.configure catchCallback: -> other: 'door fail'
        yield pretend.user('sam').send 'door X'
        result = yield @path.match pretend.lastListen()
        result.should.have.property 'other', 'door fail'

      it 'emits catch with res', -> co =>
        @path.configure catchMessage: 'no, wrong door'
        yield pretend.user('sam').send 'door X'
        yield @path.match pretend.lastListen()
        @catch.should.have.calledWith sinon.match resMatch
