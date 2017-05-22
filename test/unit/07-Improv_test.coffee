sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
chai.use require 'chai-subset'

_ = require 'lodash'
co = require 'co'

Pretend = require 'hubot-pretend'
pretend = new Pretend '../scripts/shh.coffee'
{Improv, Transcript, Director, Dialogue} = require '../../src/modules'

describe 'Improv', ->

  context 'singleton', ->

    before ->
      pretend.startup()
      @improv = Improv.get pretend.robot

    after ->
      pretend.shutdown()
      @improv.reset()

    context 'without args', ->

      it 'returns existing instance', ->
        Improv.get pretend.robot
        .should.eql @improv

      it 'still have the same robot', ->
        Improv.get pretend.robot
        .robot.should.eql pretend.robot

    context 'with args', ->

      it 'returns existing instance with new configuration', ->
        Improv.get pretend.robot, foo: 'bar'
        .should.eql @improv
        .and.have.deep.property 'config.foo'

  context 'instance', ->

    beforeEach ->
      pretend.startup()
      @tester = pretend.user 'tester', room: 'testing'
      @improv = Improv.get pretend.robot

      _.forIn @improv, (val, key) =>
        sinon.spy @improv, key if _.isFunction val

      # generate first response for mock events
      @tester.send('test').then =>
        @res = pretend.responses.incoming.pop()

    afterEach ->
      pretend.shutdown()
      @improv.reset()

      _.forIn @improv, (val, key) =>
        @improv[key].restore() if _.isFunction val

    describe 'constructor', ->

      it 'attaches response middleware to robot', ->
        pretend.robot.responseMiddleware.should.have.calledOnce

    describe '.reset', ->

      it 'restarts with defaults', ->
        @improv.config = null
        @improv.extensions = null
        @improv.reset()
        @improv.config.should.not.be.null
        @improv.extensions.should.not.be.null

    describe '.configure', ->

      it 'configures and returns singleton', ->
        result = @improv.configure admins: ['Marius', 'Sulla']
        result.should.eql @improv
        .and.have.deep.property 'config.admins'

    describe '.extend', ->

      it 'stores a function in extensions array', ->
        func = sinon.spy()
        @improv.extend func
        @improv.extensions.should.eql [func]

    describe '.mergeData', ->

      context 'with data passed as option', ->

        it 'merges data with user data', ->
          @improv.configure
            save: false
            data: instance: name: 'Hub'
          .mergeData @res.message.user
          .should.eql
            user: @res.message.user
            instance: name: 'Hub'

      context 'with data loaded from brain', ->

        it 'merges data with user data', ->
          pretend.robot.brain.set 'improv', instance: owner: 'Hubot'
          @improv.configure
            data: instance: name: 'The Hub'
          .mergeData @res.message.user
          .should.eql
            user: @res.message.user
            instance:
              owner: 'Hubot'
              name: 'The Hub'

      context 'with extension functions added', ->

        it 'merges data with results of functions', ->
          @improv
          .extend -> custom1: 'foo'
          .extend -> custom2: 'bar'
          .mergeData @res.message.user
          .should.eql
            user: @res.message.user
            custom1: 'foo'
            custom2: 'bar'

        it 'deep merges existing data with extensions', ->
          @improv.reset()
          @improv
          .extend -> user: type: 'human'
          .mergeData @res.message.user
          .should.eql
            user: _.assignIn @res.message.user, type: 'human'

    describe '.parse', ->

      # context 'with empty data', ->
      #
      #   it 'uses fallback value', ->
      #     @improv.parse ['hey {{ user.name }}, pay {{ product.price }}'], {}
      #     .should.eql ['hey unknown, pay unknown']

      context 'with deep context object', ->

        it 'populates message template with data at path', ->
          @improv.parse ['welcome to {{ instance }}'], instance: 'The Hub'
          .should.eql ['welcome to The Hub']

      ###
      #TODO: find out how to detect env language at runtime and expect correct
             values dynamically for dates etc. Travis was failing because tests
             were written with en-AU and it runs en-US
      context 'with intl disabled', ->

        it 'returns default values', ->
          @improv.parse ['{{ formatDate date }}'],
            date: new Date '2001-01-31'
          .should.eql ['31/01/2001']

      context 'with formats configured', ->

        it 'renders using configured formats', ->
          @improv.configure
            formats: date: short:
              day: 'numeric'
              month: 'long'
              year: 'numeric'
          .parse ['{{formatDate date "short"}}'], date: new Date '2001-01-31'
          .should.eql ['31 January 2001']

      context 'with locales and (possibly) ICU data', ->

        it 'renders relative values if ICU data loaded', ->
          @improv.configure
            locales: 'fr-FR'
            formats: date: short:
              day: 'numeric'
              month: 'long'
              year: 'numeric'
          localDate = @improv.parse ['{{formatDate date "short"}}'],
            date: new Date '2001-01-31'
          console.log "\tICU #{ @improv.icuInfo } (e.g. #{ localDate })"
          unless @improv.icu.icu_small
            localDate.should.eql ['31 janvier 2001']
          else
            localDate.should.eql ['31 January 2001']
      ###

    describe '.middleware', ->

      beforeEach ->
        @improv.configure data: instance: name: 'The Hub'

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
          , 'welcome to {{ instance.name }}'
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
