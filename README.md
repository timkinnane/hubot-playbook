Context and branching for chatbot conversations (with Hubot).

[![npm version](https://img.shields.io/npm/v/hubot-playbook.svg?style=flat)](https://www.npmjs.com/package/hubot-playbook)
[![Build Status](https://travis-ci.org/timkinnane/hubot-playbook.svg?branch=master)](https://travis-ci.org/timkinnane/hubot-playbook)
[![Coverage Status](https://coveralls.io/repos/github/timkinnane/hubot-playbook/badge.svg?branch=master)](https://coveralls.io/github/timkinnane/hubot-playbook?branch=master)
[![dependencies Status](https://david-dm.org/timkinnane/hubot-playbook/status.svg)](https://david-dm.org/timkinnane/hubot-playbook)
[![devDependencies Status](https://david-dm.org/timkinnane/hubot-playbook/dev-status.svg)](https://david-dm.org/timkinnane/hubot-playbook?type=dev)

[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)
[![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)
[![JavaScript Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://standardjs.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Join the chat at https://gitter.im/hubot-playbook/Lobby](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/hubot-playbook/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Important

Playbook works best with a custom fork of hubot that adds promises to middleware -
[hubot async](https://github.com/timkinnane/hubot-async) - which allows async
features. Hopefully in later versions of hubot, async will be supported and
Playbook can be used with any version from then on.

## Usage & Development

1. [Read the docs](https://timkinnane.github.io/hubot-playbook) to get an understanding of Playbook modules and their methods.

2. [See basic examples](https://github.com/timkinnane/hubot-playbook/tree/master/integration/scripts) in the integration scripts, [the outcomes of are tested here](https://github.com/timkinnane/hubot-playbook/blob/master/integration/test/Usage_test.coffee).

3. [See advanced examples](https://github.com/timkinnane/hubot-playbook/tree/master/test/unit/09-playbook_test.coffee) in the main Playbook module tests here.

Tests are run with [Hubot Pretend](https://propertyux.github.io/hubot-pretend)

## TODO

### Fixes

- Write tests for Outline module
- Replace hoooker package with middleware pattern for scene enter etc
- Queue dialogue.receive calls to ensure messages process synchronously
- Optional config for send middleware to throttle hearing consecutive res
- Display "thinking" ellipses (emit event for use by adapters)

### Docs

- Update integration tests to with unique listeners so all can be loaded at once
- Write usage examples as integration tests, with inline doc comments
- Generate usage guide docs from integration tests with annotated source
- Example setup steps for a Playbook bot without development requirements
- Add npm script to start a hubot and interact with usage examples in shell
- Contributor docs with npm script examples and commitizen ettiquite
- Make interactive demo bots, illustrating features and data inspection

### Features

- Add timing module to rate limit and schedule sends
- Integrate enter/path/branch listeners with Conditioner for semantic matchers
- Add integration tests with external-scripts and adapters (e.g. shell/irc)
- Helpers for adapter UI payloads, for buttons and cards in messenger etc
- NLP for path matching on intent params with rasa.ai
- Translate sent strings and match terms with i18n-node
