## Playbook modules

Playbook modules provide a suite of features for a dynamic conversational UI.
Sure there are plenty of node modules and Hubot scripts that will provide point
features, but they don't always play well together and often need customisation
and work-arounds for one to provide context to another, which is a major road
block for developing effective bot conversations.

The core Hubot does little more than message and callback handling,
Playbook is aimed at forming something equivalent to a Turing complete set of
conversational capabilities for bots. These modules form the central framework,
working together in context, but can still be extended as any regular Hubot.

Let's meet the modules:

### Path

Paths and their child branches are the smallest and most essential node for
conversations. Instead of listening for all triggers at all times, paths allow
matching multiple choices in a tightly scoped context.

### Dialogue

Dialogues control which paths are available to users in a given context. They
route messages to the right paths, manage timeouts, send replies and fire
callbacks for the branches matching user messages.

### Scene

Scenes are the conductors for participants engaged in dialogue with the bot.
They listen for the right context to setup a dialogue and handle multiple
concurrent users and rooms in either isolated or group dialogues as required.

### Director

Directors provide conversation firewalls, allowing listed users or external
requests to authorise or block users from entering interactions or following
specific paths.

### Transcript

A transcript records conversational events, including meta about the user,
message and module states. It is configurable to provide an overview or
drilled down analytics of specific interactions.

### Pretend

Hubot Pretend is actually an external module for unit testing Hubot
conversations. It was developed to provide a test framework for all of the
Playbook modules and interactions, but is just as useful for regular Hubots.

## Roadmap modules

What does a complete conversational UI require? Well that's an open question at
this stage, but Playbook aims to evolve to address. Here's a rough model of what
it does now and where it's going in future versions.

🤖 *Hubot* provided
📘 *Playbook* provided
📖 *Playbook* roadmap

- 🤖 listeners and callbacks
- 🤖 expression matching
- 🤖 middleware and adapters
- 🤖 brain (data store)
- 🤖 external scripts
- 📘 messaging unit tests
- 📘 conversation branching
- 📘 multi-user/room context
- 📘 authorise interactions
- 📘 event recording
- 📖 message templates
- 📖 conversation models
- 📖 translation
- 📖 natural language processing
