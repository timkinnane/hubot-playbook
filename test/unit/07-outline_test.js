const _ = require('lodash')
const sinon = require('sinon')
const chai = require('chai')
chai.should()
chai.use(require('sinon-chai'))
const pretend = require('hubot-pretend')

const Outline = require('../../src/modules/outline')

describe('Outline', () => {
  beforeEach(() => {
    pretend.start()
    Object.getOwnPropertyNames(Outline.prototype).map((key) => sinon.spy(Outline.prototype, key))
  })
  afterEach(() => {
    pretend.shutdown()
    Object.getOwnPropertyNames(Outline.prototype).map((key) => Outline.prototype[key].restore())
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
