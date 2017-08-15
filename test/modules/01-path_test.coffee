sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

_ = require 'lodash'
pretend = require 'hubot-pretend'
Path = require '../../lib/modules/path'

describe 'Path', ->

  beforeEach ->
    pretend.start()
    pretend.log.level = 'silent'
    Object.getOwnPropertyNames(Path.prototype).map (key) ->
      sinon.spy Path.prototype, key

    @mockRes = reply: sinon.spy()
    @mockDlg = send: sinon.spy()
    @callback = sinon.spy()

  afterEach ->
    pretend.shutdown()
    Object.getOwnPropertyNames(Path.prototype).map (key) ->
      Path.prototype[key].restore()

  describe 'constructor', ->

    context 'with branches', ->

      beforeEach ->
        @path = new Path pretend.robot, [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]

      it 'creates branches', ->
        @path.addBranch.args.should.eql [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]

      it 'is not closed', ->
        @path.closed.should.be.false

    context 'with a single branch', ->

      beforeEach ->
        @path = new Path pretend.robot, [ /ok/, 'OK, ok!' ]

      it 'creates branches', ->
        @path.addBranch.args.should.eql [
          [ /ok/, 'OK, ok!' ]
        ]

      it 'is not closed', ->
        @path.closed.should.be.false

    context 'with undefined branches and options', ->

      beforeEach ->
        @path = new Path pretend.robot

      it 'creates no branches', ->
        @path.addBranch.should.not.have.calledOnce

      it 'stays closed', ->
        @path.closed.should.be.true

      it 'does not throw', ->
        Path.constructor.should.not.have.threw

    context 'with bad arguments for branch', ->

      beforeEach ->
        try @path = new Path pretend.robot, 'breakme.jpg'

      it 'throws', ->
        Path.constructor.should.have.threw

  describe '.addBranch', ->

    beforeEach ->
      @path = new Path pretend.robot

    context 'with regex, message and callback', ->

      beforeEach ->
        @path.addBranch /.*/, 'foo', @callback

      it 'creates branch object', ->
        @path.branches[0].should.be.an 'object'

      it 'branch has valid regex', ->
        @path.branches[0].regex.should.be.instanceof RegExp

      it 'branch has valid handler', ->
        @path.branches[0].handler.should.be.a 'function'

      it 'opens path', ->
        @path.closed.should.be.false

      context 'when handler called', ->

        beforeEach ->
          @path.branches[0].handler @mockRes, @mockDlg

        it 'sends the message with given dialogue', ->
          @mockDlg.send.should.have.calledWith 'foo'

        it 'calls the callback with response and dialogue', ->
          @callback.should.have.calledWithExactly @mockRes, @mockDlg

    context 'with invalid regex', ->

      beforeEach ->
        try @path.addBranch 'derp'

      it 'throws', ->
        @path.addBranch.should.have.threw

    context 'with invalid message and/or callback', ->

      beforeEach ->
        try @path.addBranch /.*/
        try @path.addBranch /.*/, () ->
        try @path.addBranch /.*/, 'foo', 'bar'

      it 'always throws', ->
        @path.addBranch.should.have.alwaysThrew

  describe '.catch', ->

    context 'with message and callback in config', ->

      beforeEach ->
        @path = new Path pretend.robot,
          catchMessage: 'always be catching'
          catchCallback: @callback
        @path.catch()

      it 'returns valid handler', ->
        @path.catch.returnValues[0].handler.should.be.a 'function'

      context 'when handler called', ->

        beforeEach ->
          @path.catch().handler @mockRes, @mockDlg

        it 'sends the message with given dialogue', ->
          @mockDlg.send.should.have.calledWith 'always be catching'

        it 'calls the callback with response and dialogue', ->
          @callback.should.have.calledWithExactly @mockRes, @mockDlg

    context 'with no catch configured', ->

      it 'returns undefined', ->
        path = new Path pretend.robot
        should.not.exist path.catch()

  describe '.match', ->

    beforeEach ->
      @path = new Path pretend.robot, [
        [ /door 1/, 'foo' ]
        [ /door 2/, 'bar' ]
        [ /door 3/, 'baz' ]
      ]

    context 'with string matching branch regex', ->

      beforeEach ->
        yield pretend.user('sam').send 'door 2'
        @res = pretend.responses.incoming[0]
        @branch = @path.match @res

      it 'returns the matching branch', ->
        @branch.should.eql @path.branches[1]

      it 'updates match in response object', ->
        @res.match.should.eql 'door 2'.match @path.branches[1].regex

      it 'closes the path', ->
        @path.closed.should.be.true

    context 'with string matching multiple branches', ->

      beforeEach ->
        yield pretend.user('sam').send 'door 1 and door 2'
        @res = pretend.responses.incoming[0]
        @branch = @path.match @res

      it 'returns the first matching branch', ->
        @branch.should.eql @path.branches[0]

      it 'updates match in response object', ->
        @res.match.should.eql 'door 1 and door 2'.match @path.branches[0].regex

      it 'closes the path', ->
        @path.closed.should.be.true

    context 'with string matching no branches', ->

      beforeEach ->
        yield pretend.user('sam').send 'door X'
        @res = pretend.responses.incoming[0]
        @branch = @path.match @res

      it 'returns undefined', ->
        should.not.exist @branch

      it 'updates match in response object', ->
        should.equal @res.match, 'door X'.match @path.branches.pop().regex

      it 'path stays open', ->
        @path.closed.should.be.false
