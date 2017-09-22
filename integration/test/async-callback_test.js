const should = require('chai').should()
const pretend = require('hubot-pretend')
const wait = (delay) => new Promise((resolve, reject) => setTimeout(resolve, delay))

describe('Async Callback', () => {
  beforeEach(() => {
    pretend.start().read('scripts/async-callback.js')
  })
  afterEach(() => {
    pretend.shutdown()
  })

  context('with 100 milisecond delay', () => {
    it('replies after 100 milisecond wait', async function () {
      await pretend.user('tester').send('do async')
      await pretend.user('tester').send('wait 50')
      await wait(60) // wait for callback to complete
      pretend.messages.should.eql([
        [ 'tester', 'do async' ],
        [ 'hubot', 'Say "wait <miliseconds>" for how long.' ],
        [ 'tester', 'wait 50' ],
        [ 'hubot', 'OK, I\'ll be back in touch in 50 miliseconds.' ],
        [ 'hubot', 'Times up!!' ]
      ])
    })
    it('ends dialogue and timeout countdown', async function () {
      await pretend.user('tester').send('do async')
      await pretend.user('tester').send('wait 50')
      await wait(60) // wait for callback to complete
      let res = pretend.lastListen()
      res.dialogue.ended.should.equal(true)
      should.not.exist(res.dialogue.countdown)
    })
  })
})
