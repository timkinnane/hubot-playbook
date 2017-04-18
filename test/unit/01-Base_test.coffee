_ = require 'lodash'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Base = require '../../src/modules/Base'

Pretend = require 'hubot-pretend'
pretend = new Pretend "../scripts/shh.coffee"

class Module extends Base
  defaults: test: true
  constructor: (robot, opts) ->
    super 'module', robot, opts

describe '#Base', ->

  beforeEach ->
    pretend.startup()
    _.forIn Base.prototype, (val, key) ->
      sinon.spy Base.prototype, key if _.isFunction val

  afterEach ->
    pretend.shutdown()
    _.forIn Base.prototype, (val, key) ->
      Base.prototype[key].restore() if _.isFunction val

  describe '.constructor', ->

    context 'with name, robot and options', ->

      beforeEach ->
        @base = new Base 'test', pretend.robot, test: 'testing'

      it 'stores the robot', ->
        @base.robot.should.eql pretend.robot

      it 'generates an ID from name', ->
        @base.keygen.should.have.calledWith 'test'

      it 'stores the returned value as ID', ->
        @base.id.should.equal @base.keygen.returnValues[0]

      it 'inherits the robot logger', ->
        @base.log.should.eql pretend.robot.logger

      it 'setup config with passed options', ->
        @base.config.test.should.equal 'testing'

    context 'with different options and defaults', ->

      beforeEach ->
        Base::defaults = other: false
        @base = new Base 'test', pretend.robot, test: 'testing'

      it 'combines options and defaults in config', ->
        @base.config.should.eql other: false, test: 'testing'

    context 'with options to override defaults', ->

      beforeEach ->
        Base::defaults = test: false
        @base = new Base 'test', pretend.robot, test: true

      it 'stores options over defaults in config', ->
        @base.config.should.eql test: true

    context 'with key specified in options', ->

      beforeEach ->
        @base = new Base 'test', pretend.robot, key: 'foo'

      it 'creates composite ID from name and key', ->
        @base.id.should.match /test_foo_\d*/

    context 'without robot', ->

      beforeEach ->
        try @base = new Base 'newclass'

      it 'runs error handler', ->
        Base::error.should.have.calledOnce

      it 'does not continue to setting ID', ->
        Base::keygen.should.not.have.called

    context 'without name', ->

      beforeEach ->
        try @base = new Base()

      it 'runs error handler', ->
        Base::error.should.have.calledOnce

      it 'does not continue to setting ID', ->
        Base::keygen.should.not.have.called

  describe '.error', ->

    beforeEach ->
      @base = new Base 'test', pretend.robot, test: 'testing'

    context 'with an error', ->

      beforeEach ->
        @err = new Error "BORKED"
        try @base.error @err
        @errLog = pretend.logs.pop()

      it 'logs an error', ->
        @errLog[0].should.equal 'error'

      it 'emits the error through robot', ->
        pretend.robot.emit.should.have.calledWith 'error', @err

      it 'threw error', ->
        @base.error.should.have.threw

    context 'with error context string', ->

      beforeEach ->
        try @base.error 'something broke'
        @errLog = pretend.logs.pop()

      it 'logs an error with the module instance ID and context string', ->
        @errLog[1].should.match new RegExp "#{ @base.id }.*something broke"

      it 'emits an error through robot', ->
        pretend.robot.emit.should.have.calledWith 'error'

      it 'threw error', ->
        @base.error.should.have.threw

  describe '.keygen', ->

    beforeEach ->
      @base = new Base 'test', pretend.robot, test: 'testing'

    context 'with a key string', ->

      beforeEach ->
        @base.keygen '%.test @# String!'

      it 'uses module id prefix, key suffix (converts unsafe characters)', ->
        @base.keygen.returnValues.pop().should.match /test_\d*_test-String_\d*/

    context 'with the same source string multiple times', ->

      beforeEach ->
        @id1 = @base.keygen 'testing'
        @id2 = @base.keygen 'testing'
        @id3 = @base.keygen 'testing'

      it 'creates a unique id for each', ->
        @id1.should.not.equal(@id2).and.not.equal(@id3)

    context 'without key string', ->

      beforeEach ->
        @base.keygen()

      it 'threw error', ->
        @base.keygen.should.have.threw

  context 'inherited by new Module class with own defaults', ->

    beforeEach ->
      @module = new Module pretend.robot, other: false
      try @module.error 'an error'

    it 'stores defaults and options in config', ->
      @module.config.should.eql test: true, other: false

    it 'used the module name in super constructor as ID', ->
      @module.id.should.match /module_\d*/

    it 'calls inherited methods', ->
      Base::error.should.have.calledOnce
