sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'
co = require 'co'
_ = require 'lodash'
pretend = require 'hubot-pretend'
improv = require '../../lib/modules/improv.js'
Transcript = require '../../lib/modules/transcript.js'
Director = require '../../lib/modules/director.js'
Dialogue = require '../../lib/modules/dialogue.js'

describe 'Improv', ->
  context 'singleton', ->
    before -> pretend.start()
    after -> pretend.shutdown()

    it 'sequential use returns existing instance', ->
      improvA = improv.use pretend.robot
      improvB = improv.use pretend.robot
      improvA.should.eql improvB

    it 'instance persists after test robot shutdown', ->
      improv.instance.should.exist

    it 'use after clear returns new instance', ->
      improvA = improv.use pretend.robot
      improv.reset()
      improvB = improv.use pretend.robot
      improvA.should.not.eql improvB

    it 'overwrite robot when reused', ->
      improv.use pretend.robot
      .robot.should.eql pretend.robot

    it 'configuration merges existing config', ->
      improv.configure foo: 'bar'
      improv.configure baz: 'qux'
      improv.config.should.include foo: 'bar', baz: 'qux'

  context 'instance', ->

    beforeEach ->
      pretend.start()
      improv.use pretend.robot
      improv.configure save: false

      # generate first listen response
      pretend.robot.hear /test/, -> # listen for tests
      pretend.user('tester', { room: 'testing' }).send('test')

    afterEach ->
      pretend.shutdown()
      improv.reset()

    describe '.use', ->

      it 'attaches response middleware to robot', ->
        pretend.robot.responseMiddleware.should.have.calledOnce

    describe '.extend', ->

      it 'stores a function in extensions array', ->
        func = sinon.spy()
        improv.extend func
        improv.extensions.should.eql [func]

    describe '.remember', ->

      it 'stores data at key in context', ->
        improv.context.site = name: 'Hub'
        improv.remember 'site', lang: 'en'
        improv.context.should.eql site:
          lang: 'en'

      it 'stores data at path in context', ->
        improv.context.site = name: 'Hub'
        improv.remember 'site.lang', 'en'
        improv.context.should.eql site:
          name: 'Hub'
          lang: 'en'

    describe '.forget', ->

      it 'removes data at path in context', ->
        improv.context.site = name: 'Hub', lang: 'en'
        improv.remember 'site.lang', 'en'
        improv.context.should.eql site:
          name: 'Hub'
          lang: 'en'

    describe '.mergeData', ->

      context 'with data passed as option', ->

        it 'merges data with user data', ->
          improv.remember 'site', name: 'Hub'
          improv.mergeData pretend.lastListen().message.user
          .should.eql
            user: pretend.lastListen().message.user
            site: name: 'Hub'

      context 'with data loaded from brain', ->

        it 'merges data with user data', ->
          improv.configure save: true
          pretend.robot.brain.set 'improv', site: owner: 'Hubot'
          improv.remember 'site.name', 'Hub'
          .mergeData pretend.lastListen().message.user
          .should.eql
            user: pretend.lastListen().message.user
            site:
              owner: 'Hubot'
              name: 'Hub'

      context 'with extension functions added', ->

        it 'merges data with results of functions', ->
          improv
          .extend -> custom1: 'foo'
          .extend -> custom2: 'bar'
          .mergeData pretend.lastListen().message.user
          .should.eql
            user: pretend.lastListen().message.user
            custom1: 'foo'
            custom2: 'bar'

        it 'deep merges existing data with extensions', ->
          improv
          .extend -> user: type: 'human'
          .mergeData pretend.lastListen().message.user
          .should.eql
            user: _.assignIn pretend.lastListen().message.user, type: 'human'

    describe '.parse', ->

      context 'with context object', ->

        it 'populates message template with data at path', ->
          improv.parse ['welcome to ${ this.site }'], site: 'The Hub'
          .should.eql ['welcome to The Hub']

      context 'without context', ->

        it 'uses fallback value', ->
          context = {}
          string = 'hey ${ this.user.name }, pay ${ this.product.price }'
          improv.parse [string], context
          .should.eql ['hey unknown, pay unknown']

      context 'with partial context', ->

        it 'uses fallback for unknowns', ->
          context = product: price: '$55'
          string = 'hey ${ this.user.name }, pay ${ this.product.price }'
          improv.parse [string], context
          .should.eql ['hey unknown, pay $55']

        it 'replaces entire string as configured', ->
          improv.configure replacement: '¯\\_(ツ)_/¯'
          context = product: price: '$55'
          string = 'hey ${ this.user.name }, pay ${ this.product.price }'
          improv.parse [string], context
          .should.eql ['¯\\_(ツ)_/¯']

    describe '.middleware', ->

      beforeEach ->
        improv.remember 'site.name', 'The Hub'

      context 'with series of hubot sends', ->

        it 'rendered messages with context', -> co ->
          yield pretend.lastListen().send 'hello you'
          yield pretend.lastListen().send 'hi ${ this.user.name }'
          pretend.messages.should.eql [
            [ 'testing', 'tester', 'test' ]
            [ 'testing', 'hubot', 'hello you' ]
            [ 'testing', 'hubot', 'hi tester' ]
          ]

      context 'with multiple strings', ->

        it 'renders each message with context', -> co ->
          yield pretend.lastListen().send 'testing'
          , 'hi ${ this.user.name }'
          , 'welcome to ${ this.site.name }'
          pretend.messages.should.eql [
            [ 'testing', 'tester', 'test' ]
            [ 'testing', 'hubot', 'testing' ]
            [ 'testing', 'hubot', 'hi tester' ]
            [ 'testing', 'hubot', 'welcome to The Hub' ]
          ]

      # beforeEach ->
      #   @middleware = sinon.spy improv.middleware
      #   @parse = sinon.spy improv.parse

      # TODO: Tests below fail because spied methods are just exported clones
      # of the improv functions called by middleware (i think)

      # it 'gets called whenever robot sends', ->
      #   @middleware.should.have.calledTwice

      # it 'only parses strings with expressions', ->
      #   @parse.should.have.calledOnce
