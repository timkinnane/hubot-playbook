![Playbook Logo](https://cloud.githubusercontent.com/assets/1774379/21598936/27e49d9c-d1b9-11e6-9850-e210ddaf7fc9.png)

Conversation branching library for Hubots. Development ongoing, docs to come...

[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![npm version](https://img.shields.io/npm/v/hubot-playbook.svg?style=flat)](https://www.npmjs.com/package/hubot-playbook)
[![Build Status](https://travis-ci.org/timkinnane/hubot-playbook.svg?branch=master)](https://travis-ci.org/timkinnane/hubot-playbook)
[![Coverage Status](https://coveralls.io/repos/github/timkinnane/hubot-playbook/badge.svg?branch=master)](https://coveralls.io/github/timkinnane/hubot-playbook?branch=master)
[![dependencies Status](https://david-dm.org/timkinnane/hubot-playbook/status.svg)](https://david-dm.org/timkinnane/hubot-playbook)
[![devDependencies Status](https://david-dm.org/timkinnane/hubot-playbook/dev-status.svg)](https://david-dm.org/timkinnane/hubot-playbook?type=dev)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![Join the chat at https://gitter.im/hubot-playbook/Lobby](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/hubot-playbook/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Setup

## Prerequisites

Getting started with Playbook depends on setting up a new [Hubot](https://hubot.github.com/), then just add the Playbook library...

You will need [node.js and npm](https://docs.npmjs.com/getting-started/installing-node).
Once those are installed, we can install the hubot generator and dev tools used by Playbook:

Globals: `npm install -g coffee-script gulp-cli nodemon yo generator-hubot`

Follow the rest of the [getting started with hubot steps](https://github.com/github/hubot/blob/master/docs/index.md#getting-started-with-hubot).

Add Playbook to your bot: `npm install --save hubot-playbook`

Look at [examples] and [docs] for how to use Playbook and it's modules to add conversational logic to your bots.

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

## Development

### CLI tasks

- `gulp test` to run tests once for debugging known issues
- `gulp watch` while developing, to see tests in console
- `gulp watch --modules {name}` for quicker tests of single module
- `gulp watch --reporter {name}`
- `gulp watch --modules Scene --reporter spec` example of above combined
- `gulp docs` to review generated docs (skips running tests)
- `gulp watch:docs` while documenting code, to auto-refresh docs on edit
- `gulp watch:docs` before publishing,
- `gulp publish` to publish a completed version or patch -- TODO: this

## TODO

### Pre-release

- Create integration test, to replace diagnostics
- Fix any gaps in test coverage
- Implement semantic-release

### Beta Features

- Add context key/value collection methods from callbacks, store with user key
- Parse Playbook messages with context for template tags e.g. ok {{ username }}
- Add outline module, to define behavior models in YML and load from S3 etc

### Release Roadmap

- Fix generated docs!
- Example setup steps for a Playbook bot without development requirements
- Save/restore director config in hubot brain against key if provided
- Allow directing dialogues
- Queue dialogue.receive calls to ensure messages process synchronously
- Optional config for send middleware to throttle hearing consecutive res
- Display "thinking" ellipses (emit event for use by adapters)
- Migrate to pure ES6 and node task build and test, no coffee or gulp
- Make interactive demo bots, illustrating features
