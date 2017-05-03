_ = require 'lodash'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

Base = require '../../src/modules/Base'

Pretend = require 'hubot-pretend'
pretend = new Pretend "../scripts/shh.coffee"

class Module extends Base
  constructor: (robot, opts) ->
    @defaults = test: true
    super 'module', robot, opts

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

    context 'with name, robot and options', ->

      beforeEach ->
        @base = new Base 'test', pretend.robot, test: 'testing'

      it 'stores the robot', ->
        @base.robot.should.eql pretend.robot

      it 'inherits the robot logger', ->
        @base.log.should.eql pretend.robot.logger

      it 'setup config with passed options', ->
        @base.config.test.should.equal 'testing'

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
