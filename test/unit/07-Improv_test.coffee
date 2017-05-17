sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'
Promise = require 'bluebird'

_ = require 'lodash'
co = require 'co'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Improv, Transcript, Director, Dialogue} = require '../../src/modules'

describe 'Improv', ->

  beforeEach ->
    pretend.startup()
    @tester = pretend.user 'tester', room: 'testing'

    _.forIn Improv.prototype, (val, key) ->
      sinon.spy Improv.prototype, key if _.isFunction val

    # generate first response for mock events
    @tester.send('test').then =>
      @res = pretend.responses.incoming[0]
      @dialogue = new Dialogue @res

  afterEach ->
    pretend.shutdown()

    _.forIn Improv.prototype, (val, key) ->
      Improv.prototype[key].restore() if _.isFunction val

  describe 'constructor', ->

    context 'with defaults', ->

      it 'has no localisation data', ->
        @improv = new Improv pretend.robot
        should.not.exist @improv.intl

      it 'has no admins', ->
        @improv = new Improv pretend.robot
        @improv.admins.should.eql []

    context 'when given names of admins', ->

      it 'keeps array for later', ->
        @improv = new Improv pretend.robot, ['Marius', 'Sulla', 'Radius']
        @improv.admins.should.eql ['Marius', 'Sulla', 'Radius']

    it 'attaches response middleware to robot', ->
      @improv = new Improv pretend.robot
      pretend.robot.responseMiddleware.should.have.calledOnce

  describe '.extendData', ->

    it 'stores a function in extensions array', ->
      dataFunc = sinon.spy()
      @improv = new Improv pretend.robot
      @improv.extendData dataFunc
      @improv.extensions.should.eql [dataFunc]

  describe '.mergeData', ->

    context 'with app data passed as option', ->

      it 'merges app data with user data', ->
        @improv = new Improv pretend.robot,
          save: false
          app: instance: name: 'The Hub'
        @improv.mergeData @res.message.user
        .should.eql
          user: name: @tester.name, id: @tester.id
          app: instance: name: 'The Hub'

    context 'with app data loaded from brain', ->

      it 'merges app data with user data', ->
        pretend.robot.brain.set 'app', instance: owner: 'Hubot'
        @improv = new Improv pretend.robot,
          app: instance: name: 'The Hub'
        @improv.mergeData @res.message.user
        .should.eql
          user: name: @tester.name, id: @tester.id
          app: instance:
            owner: 'Hubot'
            name: 'The Hub'

    context 'with extension functions added', ->

      it 'merges data with results of functions', ->
        @improv = new Improv pretend.robot
        @improv.extendData -> custom1: 'foo'
        @improv.extendData -> custom2: 'bar'
        @improv.mergeData @res.message.user
        .should.eql
          user: name: @tester.name, id: @tester.id
          app: {}
          custom1: 'foo'
          custom2: 'bar'

      it 'deep merges existing data with extensions', ->
        @improv = new Improv pretend.robot
        @improv.extendData -> user: type: 'human'
        @improv.mergeData @res.message.user
        .should.eql
          user:
            name: @tester.name,
            id: @tester.id
            type: 'human'
          app: {}

  describe '.parse', ->

    beforeEach ->
      @improv = new Improv pretend.robot

    # context 'with empty data', ->
    #
    #   it 'uses fallback value', ->
    #     @improv.parse ['hey {{ user.name }}, pay {{ product.price }}'], {}
    #     .should.eql ['hey unknown, pay unknown']

    context 'with deep context object', ->

      it 'populates message template with data at path', ->
        context = instance: name: 'The Hub'
        @improv.parse ['welcome to {{ instance.name }}'], context
        .should.eql ['welcome to The Hub']

    context 'without locale configured', ->

      it 'returns default values', ->
        @improv.parse ['{{ formatDate date }}']
        , date: new Date '2001-01-31'
        .should.eql ['1/31/2001']

    context 'with locales and formats configured', ->

      beforeEach ->
        @improv.config.locales = 'fr-FR'
        @improv.config.formats.date = short:
          day: 'numeric'
          month: 'long'
          year: 'numeric'
        @dateContext = date: new Date()
        @dateStrings = ['{{ formatDate date "short"}}']

      # it 'renders relative values', ->
      #   @improv.parse @dateStrings, @dateContext
      #   .should.eql ['17 mai 2007']

  describe '.middleware', ->

    beforeEach ->
      @improv = new Improv pretend.robot,
        app: instance: name: 'The Hub'

    context 'with series of hubot sends', ->

      beforeEach ->
        @res.reply 'hello you'
        @res.reply 'hi {{ user.name }}'
        pretend.observer.next()

      it 'gets called whenever robot sends', ->
        @improv.middleware.should.have.calledTwice

    context 'when message has no tempalte tags', ->

      beforeEach ->
        @res.reply 'hello you'
        pretend.observer.next()

      it 'does not parse strings', ->
        @improv.parse.should.not.have.called

    context 'when message has template tags', ->

      beforeEach ->
        @res.send 'testing'
        , 'hi {{ user.name }}'
        , 'welcome to {{ app.instance.name }}'
        pretend.observer.next()

      it 'parses strings', ->
        @improv.parse.should.have.calledOnce

      it 'merges data with user object', ->
        @improv.mergeData.should.have.calledWith @res.message.user

      it 'sends the merged strings to room', ->
        pretend.messages.slice 2
        .should.eql [
          [ 'testing', 'hubot', 'hi tester' ]
          [ 'testing', 'hubot', 'welcome to The Hub' ]
        ]
