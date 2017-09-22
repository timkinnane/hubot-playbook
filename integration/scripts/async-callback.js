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
//   do async - it will ask how long to delay response
//   wait <miliseconds> - it will reply after the number of miliseconds
//
// Author:
//   Tim Kinnane
//
const playbook = require('../../src')

const wait = (delay) => new Promise((resolve, reject) => setTimeout(resolve, delay))

module.exports = (robot) => {
  playbook.use(robot)
  playbook.sceneHear(/do async/, (res) => {
    res.dialogue.addPath('Say "wait <miliseconds>" for how long.', [
      [ /wait (.*)/, async function (res) {
        let miliseconds = parseInt(res.match[1])
        if (!Number.isInteger(miliseconds)) {
          res.dialogue.send('sorry that\'s not an integer')
          return
        }
        res.dialogue.send(`OK, I'll be back in touch in ${miliseconds} miliseconds.`)
        await wait(miliseconds)
        res.dialogue.send('Times up!!')
      } ]
    ])
  })
}
