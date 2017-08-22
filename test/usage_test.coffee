sinon = require 'sinon'
chai = require 'chai'
should = chai.should()
chai.use require 'sinon-chai'

describe 'Require module', ->

  context 'Playbook as default', ->

    it 'loads only Playbook', ->
      playbook = require '../lib'
      console.log playbook
