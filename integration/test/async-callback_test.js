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

  context('with 20 milisecond delay', () => {
    it('replies after 20 milisecond wait', async function () {
      await pretend.user('tester').send('async')
      await pretend.user('tester').send('count 20')
      await pretend.user('tester').send('start')
      await wait(30) // wait for callback to complete
      pretend.messages.should.eql([
        [ 'tester', 'async' ],
        [ 'hubot', 'Say "count <miliseconds>" for how many miliseconds I should count.' ],
        [ 'tester', 'count 20' ],
        [ 'hubot', 'OK, I\'ll count to 20 miliseconds. Say "start" when you want me to start' ],
        [ 'tester', 'start' ],
        [ 'hubot', 'Counting...' ],
        [ 'hubot', 'Done!' ]
      ])
    })
    it('does not send timeout message after delay', async function () {
      await pretend.user('tester').send('async')
      await pretend.user('tester').send('count 20')
      await pretend.user('tester').send('start')
      await wait(30) // allow time to make sure no timeout messages
    })
    it('ends dialogue and timeout countdown', async function () {
      await pretend.user('tester').send('async')
      await pretend.user('tester').send('count 20')
      await pretend.user('tester').send('start')
      await wait(30) // wait for callback to complete
      let res = pretend.lastListen()
      res.dialogue.ended.should.equal(true)
      should.not.exist(res.dialogue.countdown)
    })
  })
})
