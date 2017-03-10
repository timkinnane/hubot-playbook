![Playbook Logo](https://cloud.githubusercontent.com/assets/1774379/21598936/27e49d9c-d1b9-11e6-9850-e210ddaf7fc9.png)

Conversation branching library for Hubots. Development ongoing, docs to come...

[![Build Status](https://travis-ci.org/timkinnane/hubot-playbook.svg?branch=master)](https://travis-ci.org/timkinnane/hubot-playbook)

[![Coverage Status](https://coveralls.io/repos/github/timkinnane/hubot-playbook/badge.svg?branch=master)](https://coveralls.io/github/timkinnane/hubot-playbook?branch=master)

[![Join the chat at https://gitter.im/hubot-playbook/Lobby](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/hubot-playbook/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Setup

## Prerequisites

Getting started with Playbook depends on setting up a new [Hubot](https://hubot.github.com/), then just add the Playbook library...

You will need [node.js and npm](https://docs.npmjs.com/getting-started/installing-node).
Once those are installed, we can install the hubot generator and dev tools used by Playbook:

Globals: `npm install -g coffee-script gulp nodemon yo generator-hubot`

Follow the rest of the [getting started with hubot steps](https://github.com/github/hubot/blob/master/docs/index.md#getting-started-with-hubot).

Add Playbook to your bot: `npm install --save hubot-playbook`

Look at [examples] and [docs] for how to use Playbook and it's modules to add conversational logic to your bots.

@TODO: generate docs!

@TODO: distinct setup steps for spinning up a Playbook bot without development requirements.

## Required reading

*Framework*

- [Hubot Scripting](https://github.com/github/hubot/blob/master/docs/scripting.md)
- [Coffeescript](http://coffeescript.org/)
- [Underscore](http://underscorejs.org/)

*Testing*

- [Mochajs](https://mochajs.org/)
- [Chaijs (should)](http://chaijs.com/api/bdd/)
- [Sinon Spies](http://sinonjs.org/releases/v1.17.7/spies/)
- [Hubot Test Helper](https://github.com/mtsmfm/hubot-test-helper)
