Q = require 'q'
_ = require 'underscore'
mute = require 'mute'
{inspect} = require 'util'
sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'
Helpers = require '../../src/Playbook'

describe '#Helpers', ->

  describe '.keygen', ->

    context 'with a source string', ->

      beforeEach ->
        @result = Helpers.keygen '%.test @# String!'

      it 'converts or removes unsafe characters', ->
        @result.should.equal 'test-String'

    context 'without source', ->

      beforeEach ->
        @result = Helpers.keygen()

      it 'creates a string of 8 random characters', ->
        @result.length.should.equal 8
