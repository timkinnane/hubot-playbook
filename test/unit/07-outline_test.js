const _ = require('lodash')
const sinon = require('sinon')
const chai = require('chai')
const should = chai.should()
chai.use(require('sinon-chai'))
const pretend = require('hubot-pretend')

const Outline = require('../../src/modules/outline')

describe('Outline', () => {
  beforeEach(() => {
    pretend.start()
    pretend.log.level = 'silent'
    Object.getOwnPropertyNames(Outline.prototype).map((key) => sinon.spy(Outline.prototype, key))
  })
  afterEach(() => {
    pretend.shutdown()
    Object.getOwnPropertyNames(Outline.prototype).map((key) => Outline.prototype[key].restore())
  })

  describe('constructor', () => {
    context('with bit missing a key', () => {
      it('throws an error', () => {
        let bits = [{ condition: /test/i, send: 'testing' }]
        let outline, err
        try {
          outline = new Outline(pretend.robot, bits)
        } catch (e) {
          err = e
        }
        err.should.be.instanceof(Error)
        err.message.should.match(/key/)
        should.not.exist(outline)
      })
    })
  })

  describe('.bitCondition', () => {
    context('with regex condition', () => {
      it('returns exact regex for bit\'s condition', () => {
        let bits = [{ key: 'testing', condition: /test/i }]
        let outline = new Outline(pretend.robot, bits)
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.bitCondition('testing')).should.equal(true)
        testString.match(outline.bitCondition('testing')).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.bitCondition('testing')))
      })
    })
    context('with string contraining regex', () => {
      it('creates a valid regex from content of string', () => {
        let bits = [{ key: 'testing', condition: '/test/i' }]
        let outline = new Outline(pretend.robot, bits)
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.bitCondition('testing')).should.equal(true)
        testString.match(outline.bitCondition('testing')).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.bitCondition('testing')))
      })
    })
    context('with simple word only string', () => {
      it('creates a valid (case-insensative) regex from word', () => {
        let bits = [{ key: 'testing', condition: 'test' }]
        let outline = new Outline(pretend.robot, bits)
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.bitCondition('testing')).should.equal(true)
        testString.match(outline.bitCondition('testing')).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.bitCondition('testing')))
      })
    })
  })
})

// TODO: outline attributes for directors:
// - username/roomAuth: if given, creates lambda for Director authorise method
// e.g.
// if usernameAuth? or roomAuth?
//   authorise = (username, room, res) =>
//     if usernameAuth?
//       if @robot.adapter.callMethod usernameAuth
//       , username
//       , res.message.user.name
//         return true
//     if roomAuth?
//       if @robot.adapter.callMethod roomAuth
//       , username
//       , res.message.user.name
//         return true
//     return false
