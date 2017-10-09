const _ = require('lodash')
const sinon = require('sinon')
const chai = require('chai')
const should = chai.should()
chai.use(require('sinon-chai'))
chai.use(require('chai-subset'))
const pretend = require('hubot-pretend')

const Outline = require('../../src/modules/outline')
const Dialogue = require('../../src/modules/dialogue')
let playbook = require('../../src/modules/playbook')

describe('Outline', () => {
  beforeEach(() => {
    pretend.start()
    pretend.log.level = 'silent'
    Object.getOwnPropertyNames(Outline.prototype).map((key) => sinon.spy(Outline.prototype, key))
    playbook.use(pretend.robot)
  })
  afterEach(() => {
    pretend.shutdown()
    Object.getOwnPropertyNames(Outline.prototype).map((key) => Outline.prototype[key].restore())
    playbook = playbook.reset()
  })

  describe('constructor', () => {
    context('without options', () => {
      beforeEach(() => {
        Outline.prototype.setupScenes.restore() // replace spy
        sinon.stub(Outline.prototype, 'setupScenes') // with stub
      })
      it('calls setupScenes', () => {
        let outline = new Outline(pretend.robot, [
          { key: 'foo', condition: /foo/i, send: 'foo' },
          { key: 'bar', condition: /bar/i, send: 'bar', listen: 'hear' }
        ])
        outline.setupScenes.should.have.calledWith()
      })
    })
    context('with setupScenes option disabled', () => {
      it('does not call setupScenes', () => {
        let outline = new Outline(pretend.robot, [
          { key: 'foo', condition: /foo/i, send: 'foo' },
          { key: 'bar', condition: /bar/i, send: 'bar', listen: 'hear' }
        ], { setupScenes: false })
        outline.setupScenes.should.not.have.calledWith()
      })
    })
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

  describe('.getByKey', () => {
    it('returns bit with given key', () => {
      let outline = new Outline(pretend.robot, [
        { key: 'foo', condition: /foo/i, send: 'foo' },
        { key: 'bar', condition: /bar/i, send: 'bar' }
      ], { setupScenes: false })
      outline.getByKey('foo')
      .should.eql({ key: 'foo', condition: /foo/i, send: 'foo' })
    })
    it('throws if key is not found / invalid', () => {
      let outline = new Outline(pretend.robot, [
        { key: 'foo', condition: /foo/i, send: 'foo' },
        { key: 'bar', condition: /bar/i, send: 'bar' }
      ], { setupScenes: false })
      let result, err
      try {
        result = outline.getByKey('baz')
      } catch (e) {
        err = e
      }
      err.should.be.instanceof(Error)
      err.message.should.match(/invalid/)
      should.not.exist(result)
    })
  })

  describe('.parseCondition', () => {
    context('with regex condition', () => {
      it('returns exact regex for bit\'s condition', () => {
        let bits = [{ key: 'testing', condition: /test/i }]
        let outline = new Outline(pretend.robot, bits, { setupScenes: false })
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.parseCondition(bits[0].condition)).should.equal(true)
        testString.match(outline.parseCondition(bits[0].condition)).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.parseCondition(bits[0].condition)))
      })
    })
    context('with string contraining regex', () => {
      it('creates a valid regex from content of string', () => {
        let bits = [{ key: 'testing', condition: '/test/i' }]
        let outline = new Outline(pretend.robot, bits, { setupScenes: false })
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.parseCondition(bits[0].condition)).should.equal(true)
        testString.match(outline.parseCondition(bits[0].condition)).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.parseCondition(bits[0].condition)))
      })
    })
    context('with simple word only string', () => {
      it('creates a valid (case-insensative) regex from word', () => {
        let bits = [{ key: 'testing', condition: 'test' }]
        let outline = new Outline(pretend.robot, bits, { setupScenes: false })
        let testString = 'Test'
        let testMatch = testString.match(/test/i)
        _.isRegExp(outline.parseCondition(bits[0].condition)).should.equal(true)
        testString.match(outline.parseCondition(bits[0].condition)).should.eql(testMatch)
        // console.log(bits[0].condition, testString.match(outline.parseCondition(bits[0].condition)))
      })
    })
  })

  describe('setupScenes', () => {
    context('without Playbook', () => {
      it('throws', () => {
        delete pretend.robot.playbook
        let outline = new Outline(pretend.robot, [
          { key: 'foo', condition: /foo/i, send: 'foo' },
          { key: 'bar', condition: /bar/i, send: 'bar', listen: 'hear' }
        ], { setupScenes: false })
        try { outline.setupScenes() } catch (e) {}
        outline.setupScenes.should.have.thrown('Error')
      })
    })
    context('with Playbook', () => {
      it('calls sceneListen on Playbook with bit args', () => {
        sinon.spy(playbook, 'sceneListen')
        let outline = new Outline(pretend.robot, [
          { key: 'foo', condition: /foo/i, send: 'foo' },
          {
            key: 'bar',
            condition: /bar/i,
            send: 'bar',
            listen: 'hear',
            options: { timeout: 100, scope: 'direct' }
          },
          { key: 'baz', condition: /baz/i, send: 'baz' }
        ], { setupScenes: false })
        outline.setupScenes()
        playbook.sceneListen.should.have.calledOnce // eslint-disable-line
        playbook.sceneListen.should.have.calledWithExactly(
          'hear', /bar/i, { timeout: 100, scope: 'direct' }, 'bar', sinon.match.func
        )
      })
      it('returns the outline for chaining', () => {
        let outline = new Outline(pretend.robot, [
          { key: 'foo', condition: /foo/i, send: 'foo' },
          { key: 'bar', condition: /bar/i, send: 'bar' }
        ], { setupScenes: false })
        outline.setupScenes()
        .should.eql(outline)
      })
    })
  })

  describe('.setupDialogue', () => {
    it('adds bit options to dialogue config', () => {
      let res = pretend.response('tester', 'test')
      let outline = new Outline(pretend.robot)
      let dialogue = new Dialogue(res)
      res.dialogue = dialogue
      res.bit = {
        key: 'foo',
        condition: /foo/i,
        send: 'foo',
        listen: 'hear',
        options: { timeout: 100, scope: 'direct' }
      }
      outline.setupDialogue(res)
      dialogue.config.should.containSubset({
        timeout: 100, scope: 'direct'
      })
    })
  })

  describe('.bitCallback', () => {
    it('returns promise', () => {
      let res = pretend.response('tester', 'test')
      let outline = new Outline(pretend.robot)
      res.dialogue = new Dialogue(res)
      let bit = { key: 'foo', condition: /foo/i, send: 'foo' }
      outline.bitCallback(bit, res)
      .then.should.be.a('function')
    })
    it('adds bit to res', () => {
      let res = pretend.response('tester', 'test')
      let outline = new Outline(pretend.robot)
      res.dialogue = new Dialogue(res)
      let bit = { key: 'foo', condition: /foo/i, send: 'foo' }
      outline.bitCallback(bit, res)
      res.bit.should.eql(bit)
    })
    it('sets up dialogue', async function () {
      let res = pretend.response('tester', 'test')
      let outline = new Outline(pretend.robot)
      res.dialogue = new Dialogue(res)
      let bit = { key: 'foo', condition: /foo/i, send: 'foo' }
      await outline.bitCallback(bit, res)
      outline.setupDialogue.should.have.calledWith(res)
    })
    it('sends bit send strings', async function () {
      let res = pretend.response('tester', 'test')
      let outline = new Outline(pretend.robot)
      res.dialogue = new Dialogue(res)
      let bit = { key: 'foo', condition: /foo/i, send: ['foo', 'bar'] }
      await outline.bitCallback(bit, res)
      pretend.messages.should.eql([
        [ 'hubot', 'foo' ],
        [ 'hubot', 'bar' ]
      ])
    })
    context('with bits to do next', () => {
      it('sets up paths', async function () {
        let res = pretend.response('tester', 'test')
        let bits = [
          { key: 'foo', condition: /foo/i, send: 'foo', next: ['bar'] },
          { key: 'bar', condition: /bar/i, send: 'bar' }
        ]
        let outline = new Outline(pretend.robot, bits)
        res.dialogue = new Dialogue(res)
        await outline.bitCallback(bits[0], res)
        outline.setupPath.should.have.calledWith(res)
      })
    })
    context('with nothing to do next', () => {
      it('resolves without setting up path', async function () {
        let res = pretend.response('tester', 'test')
        let bits = [{ key: 'foo', condition: /foo/i, send: 'foo' }]
        let outline = new Outline(pretend.robot, bits)
        res.dialogue = new Dialogue(res)
        outline.bitCallback(bits[0], res)
        outline.setupPath.should.not.have.calledOnce // eslint-disable-line
      })
    })
  })

  describe('.setupPath', () => {
    it('creates path and branches for next bits', () => {
      let res = pretend.response('tester', 'test')
      let bits = [
        { key: 'foo', condition: /foo/i, send: 'foo', next: ['bar', 'baz'] },
        { key: 'bar', condition: /bar/i, send: 'bar' },
        { key: 'baz', condition: /baz/i, send: 'baz' }
      ]
      let outline = new Outline(pretend.robot, bits)
      res.dialogue = new Dialogue(res)
      res.dialogue.addPath = sinon.spy()
      res.bit = bits[0]
      outline.setupPath(res)
      res.dialogue.addPath.should.have.calledWith([
        [/bar/i, sinon.match.func],
        [/baz/i, sinon.match.func]
      ]) // eslint-disable-line
    })
    it('added bit catch property as path option', async function () {
      let res = pretend.response('tester', 'test')
      let bits = [
        { key: 'foo', condition: /foo/i, send: 'foo', next: ['bar'], catch: 'foo?' },
        { key: 'bar', condition: /bar/i, send: 'bar' }
      ]
      let outline = new Outline(pretend.robot, bits)
      res.dialogue = new Dialogue(res)
      res.bit = bits[0]
      await outline.setupPath(res)
      res.dialogue.path.config.catchMessage.should.equal(bits[0].catch)
    })
    // TODO: move this to usage examples
    it('executes cyclical interaction from connected bits', async function () {
      pretend.robot.playbook.outline([
        { key: 'foo', condition: /foo/i, send: 'foo!', next: ['bar', 'baz'], listen: 'hear' },
        { key: 'bar', condition: /bar/i, send: 'bar!', next: ['foo', 'baz'] },
        { key: 'baz', condition: /bar/i, send: 'bar!', next: ['foo', 'bar'] }
      ])
      await pretend.user('tester').send('foo?')
      await pretend.user('tester').send('bar?')
      await pretend.user('tester').send('baz?')
      await pretend.user('tester').send('foo?')
      await pretend.user('tester').send('baz?')
      await pretend.user('tester').send('bar?')
      pretend.messages.should.eql([
        [ 'tester', 'foo?' ],
        [ 'hubot', 'foo!' ],
        [ 'tester', 'bar?' ],
        [ 'hubot', 'bar!' ],
        [ 'tester', 'baz?' ],
        [ 'tester', 'foo?' ],
        [ 'hubot', 'foo!' ],
        [ 'tester', 'baz?' ],
        [ 'tester', 'bar?' ],
        [ 'hubot', 'bar!' ]
      ])
    })
  }) // options: { timeout: 10, timeoutText: 'bar timeout' }
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
