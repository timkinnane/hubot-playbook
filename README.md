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
[![License](http://img.shields.io/badge/license-MIT-yellow.svg?style=flat)](https://github.com/timkinnane/hubot-playbook/blob/master/LICENSE.md)

## Usage & Development

Playbook is a conversation branching library for Hubots, with many utilities.

It's still in pre-release state and docs are on the way, but if you'd like to
start using stable builds, please look at the demo used for integration testing.

[Demo scripts](demo/scripts) illustrating conversation processing, and are [tested](demo/test/Usage_test.coffee) by [Hubot Pretend](https://github.com/timkinnane/hubot-pretend)

[See the first draft doc regarding modules and provided features here](docs/modules.md).

## TODO

### Beta in development

- Add methods for users to populate data for template tag context with Improv
- Load outlines from yaml (including external stores like S3)
- Integrate enter/path/branch listeners with Conditioner for semantic matchers

### Slated refactors

- Improve Improv to parse with internationalization
- Update Dialogue to return promise on send and receive
- Replace hoooker package with Hubot middleware, for scene enter etc
- Update demo bot tests to with unique listeners so all can be loaded at once
- Add demo bot integration tests with external-scripts and adapters (e.g. shell)
- Add `npm run shell` to test demo bot interactions directly (without pretend)
- Allow chaining constructors and methods, e.g. scene().direct().transcribe()

### Documentation

- Contributor docs with npm script examples and commitizen ettiquite
- Generated docs and demo usage code with docco and jsDoc templates
- Example setup steps for a Playbook bot without development requirements

### Release Roadmap

- Helpers for adapter UI payloads, for buttons and cards in messenger etc
- Translate sent strings and match terms with i18n-node
- NLP for dialogue handlers with rasa.ai
- Queue dialogue.receive calls to ensure messages process synchronously
- Optional config for send middleware to throttle hearing consecutive res
- Display "thinking" ellipses (emit event for use by adapters)
- Migrate to pure ES6 and node task build and test, no coffee?
- Make Playbook run as stand alone bin, read scripts directly, wrapping Hubot
- Make interactive demo bots, illustrating features and data inspection
