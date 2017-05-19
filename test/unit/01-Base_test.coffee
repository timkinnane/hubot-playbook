sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

_ = require 'lodash'

Pretend = require 'hubot-pretend'
pretend = new Pretend "../scripts/shh.coffee"
{Base} = require '../../src/modules'

class Module extends Base
  constructor: (robot, args...) ->
    @config = test: true
    super 'module', robot, args...

describe 'Base', ->

  beforeEach ->
    pretend.startup()
    _.forIn Base.prototype, (val, key) ->
      sinon.spy Base.prototype, key if _.isFunction val

  afterEach ->
    pretend.shutdown()
    _.forIn Base.prototype, (val, key) ->
      Base.prototype[key].restore() if _.isFunction val

  describe '.constructor', ->

    context 'with name, robot and options and key', ->

      beforeEach ->
        @base = new Base 'test', pretend.robot, test: 'testing', 'basey-mcbase'

      it 'stores the robot', ->
        @base.robot.should.eql pretend.robot

      it 'inherits the robot logger', ->
        @base.log.should.eql pretend.robot.logger

      it 'calls configure with options', ->
        @base.configure.should.have.calledWith test: 'testing'

      it 'sets key attribute', ->
        @base.key.should.equal 'basey-mcbase'

    context 'without robot', ->

      beforeEach ->
        try @base = new Base 'newclass'

      it 'runs error handler', ->
        Base::error.should.have.calledOnce

    context 'without name', ->

      beforeEach ->
        try @base = new Base()

      it 'runs error handler', ->
        Base::error.should.have.calledOnce

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

    context 'using inherited method for error', ->

      beforeEach ->
        @module = new Module pretend.robot
        try @module.error 'Throw me an error'

      it 'calls inherited method', ->
        Base::error.should.have.calledWith 'Throw me an error'

      it 'threw', ->
        @module.error.should.have.threw

  describe '.configure', ->

    beforeEach ->
      @base = new Base 'module', pretend.robot,
        setting: true
        deep:
          foo: 'bar'
          baz: false

    it 'saves new options', ->
      @base.configure foo: true
      @base.config.foo.should.be.true

    it 'overrides existing config', ->
      @base.configure setting: false
      @base.config.setting.should.be.false

    it 'overrides deep attributes', ->
      @base.configure deep: baz: true
      @base.config.should.eql
        setting: true
        deep:
          foo: 'bar'
          baz: true

    it 'throws when not given options', ->
      try @base.configure 'not an object'
      @base.configure.should.have.threw

    context 'with config inherited from module', ->

      beforeEach ->
        @module = new Module pretend.robot

      it 'used inherited config', ->
        @module.config.test.should.be.true

      it 'overwrites inherited when options conflict', ->
        @module.configure test: false
        @module.config.test.should.be.false

  describe '.emit', ->

    it 'emits event via the robot with instance as first arg', ->
      @mockEvent = sinon.spy()
      pretend.robot.on 'mockEvent', @mockEvent
      @base = new Base 'module', pretend.robot
      @base.emit 'mockEvent', foo: 'bar'
      @mockEvent.should.have.calledWith @base, foo: 'bar'

  describe '.on', ->

    beforeEach ->
      @mockEvent = sinon.spy()

    it 'relays events from robot with instance as first arg', ->
      @base = new Base 'module', pretend.robot
      @mockEvent = sinon.spy()
      @base.on 'mockEvent', @mockEvent
      pretend.robot.emit 'mockEvent', @base, foo: 'bar'
      @mockEvent.should.have.calledWith @base, foo: 'bar'
