_ = require 'underscore'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
Helpers = require '../../src/modules/Helpers'

describe '#Helpers', ->

  beforeEach ->
    _.map _.keys(Helpers), (key) -> sinon.spy Helpers, key # spy on helpers

  afterEach ->
    _.map _.keys(Helpers), (key) -> Helpers[key].restore()

  describe '.keygen', ->

    context 'with a source string', ->

      beforeEach ->
        Helpers.keygen 'unit', '%.test @# String!'

      it 'uses source as prefix, converting unsafe characters', ->
        Helpers.keygen.returnValues[0].should.match /^unit_test-String_/

    context 'without source', ->

      beforeEach ->
        Helpers.keygen 'unit'

      it 'creates a random string', ->
        Helpers.keygen.returnValues[0].should.be.a 'string'

    context 'without scope or source', ->

      beforeEach ->
        try Helpers.keygen()

      it 'throws an error', ->
        Helpers.keygen.should.have.threw

    context 'twice with the same source string', ->

      beforeEach ->
        @id1 = Helpers.keygen 'unit', 'testing'
        @id2 = Helpers.keygen 'unit', 'testing'

      it 'creates a unique id for each', ->
        @id1.should.not.equal @id2
