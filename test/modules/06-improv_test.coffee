sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'

_ = require 'lodash'
pretend = require 'hubot-pretend'
improv = require '../../lib/modules/improv'
Transcript = require '../../lib/modules/transcript'
Director = require '../../lib/modules/director'
Dialogue = require '../../lib/modules/dialogue'

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

      # generate first response for mock events
      pretend.user('tester', { room: 'testing' }).send('test').then =>
        @res = pretend.responses.incoming.pop()

    afterEach ->
      pretend.shutdown()
      improv.reset()

    it 'passes my funky string', ->
      string = 'hey ${ this.user.name }, pay ${ this.product.price }'
      console.log improv.parse [string], {
        product: price: '$55'
      }

###
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
        improv.context.instance = name: 'Hub'
        improv.remember 'instance', lang: 'en'
        improv.context.should.eql instance:
          lang: 'en'

      it 'stores data at path in context', ->
        improv.context.instance = name: 'Hub'
        improv.remember 'instance.lang', 'en'
        improv.context.should.eql instance:
          name: 'Hub'
          lang: 'en'

    describe '.mergeData', ->

      context 'with data passed as option', ->

        it 'merges data with user data', ->
          improv.remember 'instance', name: 'Hub'
          improv.mergeData @res.message.user
          .should.eql
            user: @res.message.user
            instance: name: 'Hub'

      context 'with data loaded from brain', ->

        it 'merges data with user data', ->
          improv.configure save: true
          pretend.robot.brain.set 'improv', instance: owner: 'Hubot'
          improv.remember 'instance.name', 'Hub'
          .mergeData @res.message.user
          .should.eql
            user: @res.message.user
            instance:
              owner: 'Hubot'
              name: 'Hub'

      context 'with extension functions added', ->

        it 'merges data with results of functions', ->
          improv
          .extend -> custom1: 'foo'
          .extend -> custom2: 'bar'
          .mergeData @res.message.user
          .should.eql
            user: @res.message.user
            custom1: 'foo'
            custom2: 'bar'

        it 'deep merges existing data with extensions', ->
          improv
          .extend -> user: type: 'human'
          .mergeData @res.message.user
          .should.eql
            user: _.assignIn @res.message.user, type: 'human'

    describe '.parse', ->

      context 'with empty data', ->

        it 'uses fallback value', ->
          improv.parse ['hey ${ user.name }, pay ${ product.price }'], {}
          .should.eql ['hey unknown, pay unknown']

      context 'with deep context object', ->

        it 'populates message template with data at path', ->
          improv.parse ['welcome to ${ instance }'], instance: 'The Hub'
          .should.eql ['welcome to The Hub']

    describe '.middleware', ->

      beforeEach ->
        improv.configure data: instance: name: 'The Hub'

      context 'with series of hubot sends', ->

        beforeEach ->
          @res.reply 'hello you'
          @res.reply 'hi ${ user.name }'
          pretend.observer.next()

        it 'gets called whenever robot sends', ->
          @improv.middleware.should.have.calledTwice

      context 'when message has no tempalte tags', ->

        beforeEach ->
          @res.reply 'hello you'
          wait = pretend.observer.next()

        it 'does not parse strings', ->
          @improv.parse.should.not.have.called

      context 'when message has template tags', ->

        beforeEach ->
          @res.send 'testing'
          , 'hi ${ user.name }'
          , 'welcome to ${ instance.name }'

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
###
