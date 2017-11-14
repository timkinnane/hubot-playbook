// Description:
//   Have an asynchronous conversation
//
// Dependencies:
//   hubot-playbook
//   async/await (node v8)
//
// Configuration:
//   N/A
//
// Commands:
//   async - it will ask how long to delay response
//   count <miliseconds> - it will reply after the number of miliseconds
//   start - it starts counting miliseconds
//
// Author:
//   Tim Kinnane
//
const playbook = require('../../lib')

const wait = (delay) => new Promise((resolve, reject) => setTimeout(resolve, delay))

class AsyncConversation {
  constructor (res) {
    let prompt = `Say "count <miliseconds>" for how many miliseconds I should count.`
    res.dialogue.addPath(prompt, [[ /count (.*)/, this.count.bind(this) ]], 'async-setup')
  }
  count (res) {
    this.miliseconds = parseInt(res.match[1])
    if (!Number.isInteger(this.miliseconds)) {
      return res.dialogue.send('sorry that\'s not an integer')
    }
    let prompt = `OK, I'll count to ${this.miliseconds} miliseconds. Say "start" when you want me to start`
    return res.dialogue.addPath(prompt, [[ /start/, this.start.bind(this) ]], 'async-count')
  }
  async start (res) {
    await res.dialogue.send('Counting...')
    await wait(this.miliseconds)
    return res.dialogue.send('Done!')
  }
}

module.exports = robot => {
  playbook.use(robot)
  playbook.sceneHear(/async/, {
    timeout: 10
  }, 'async-conversation', (res) => new AsyncConversation(res))
}
