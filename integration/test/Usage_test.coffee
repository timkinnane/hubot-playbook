_ = require 'lodash'
co = require 'co'
chai = require 'chai'
should = chai.should()
pretend = require 'hubot-pretend'

# director methods are async, need to allow enter middleware time to process
wait = (delay) -> new Promise (resolve, reject) -> setTimeout resolve, delay

describe 'Playbook demo', ->

  afterEach ->
    pretend.shutdown().clear()

  context 'knock knock test - user scene', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-knock-user.coffee'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'

    context 'Nima begins in A, continues in B, Pema tries in both', ->

      it 'responds to Nima in both, ignores Pema in both', -> co =>
        yield @nima.in('#A').send "knock knock" # ... Who's there?
        yield @pema.in('#A').send "Pema A"      # ... -ignored-
        yield @nima.in('#B').send "Nima B"      # ... Nima B who?
        yield @pema.in('#B').send "Pema B"      # ... -ignored-
        pretend.messages.should.eql [
          [ '#A', 'nima',   "knock knock" ]
          [ '#A', 'hubot',  "Who's there?" ]
          [ '#A', 'pema',   "Pema A" ]
          [ '#B', 'nima',   "Nima B" ]
          [ '#B', 'hubot',  "Nima B who?" ]
          [ '#B', 'pema',   "Pema B" ]
        ]

  context 'knock knock test - room scene', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-knock-room.coffee'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'
      @A = pretend.room '#A'
      @B = pretend.room '#B'

    context 'Nima begins in A, continues in B, Pema responds in A', ->

      it 'responds to Nima or Pema in A', -> co =>
        yield @A.receive @nima, "knock knock"   # ... Who's there?
        yield @B.receive @nima, "Nima"          # ... -ignored-
        yield @A.receive @pema, "Pema"          # ... Pema who?
        yield @B.receive @pema, "Pema B"        # ... -ignored-
        yield @A.receive @nima, "No it's Nima!" # ... No it's Nima who?
        @A.messages().should.eql [
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "@nima Who's there?" ]
          [ 'pema',   "Pema" ]
          [ 'hubot',  "@pema Pema who?" ]
          [ 'nima',   "No it's Nima!" ]
          [ 'hubot',  "@nima lol" ]
        ]

      it 'ignores both in B', -> co =>
        yield @A.receive @nima, "knock knock"   # ... Who's there?
        yield @B.receive @nima, "Nima"          # ... -ignored-
        yield @A.receive @pema, "Pema"          # ... Pema who?
        yield @B.receive @pema, "Pema B"        # ... -ignored-
        yield @A.receive @nima, "No it's Nima!" # ... No it's Nima who?
        @B.messages().should.eql [
          [ 'nima',   "Nima" ]
          [ 'pema',   "Pema B" ]
        ]

  context 'knock knock test - direct scene', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-knock-direct-noreply.coffee'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'
      @A = pretend.room '#A'
      @B = pretend.room '#B'

    context 'Nima begins in A, continues in both, Pema responds in A', ->

      it 'responds only to Nima in A', -> co =>
        yield @A.receive @nima, "knock knock" # ... Who's there?
        yield @B.receive @nima, "Nima"        # ... -ignored-
        yield @A.receive @pema, "Pema"        # ... -ignored-
        yield @B.receive @pema, "Pema B"      # ... -ignored-
        yield @A.receive @nima, "Nima"        # ... Nima who?
        yield @A.receive @nima, "Nima A"      # ... lol
        @A.messages().should.eql [
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "Who's there?" ]
          [ 'pema',   "Pema" ]
          [ 'nima',   "Nima" ]
          [ 'hubot',  "Nima who?" ]
          [ 'nima',   "Nima A" ]
          [ 'hubot',  "lol" ]
        ]

      it 'ignores both in B', -> co =>
        yield @A.receive @nima, "knock knock" # ... Who's there?
        yield @B.receive @nima, "Nima"        # ... -ignored-
        yield @A.receive @pema, "Pema"        # ... -ignored-
        yield @B.receive @pema, "Pema B"      # ... -ignored-
        yield @A.receive @nima, "Nima"        # ... Nima who?
        yield @A.receive @nima, "Nima A"      # ... lol
        @B.messages().should.eql [
          [ 'nima', "Nima" ]
          [ 'pema', "Pema B" ]
        ]

  context 'knock knock test - parallel direct scenes + reply', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-knock-direct-reply.coffee'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'

    context 'Nima begins, Pema begins, both continue in same room', ->

      it 'responds to both without conflict', -> co =>
        yield @nima.send "knock knock"  # ... Who's there?
        yield @pema.send "knock knock"  # ... Who's there?
        yield @nima.send "Nima"         # ... Nima who?
        yield @pema.send "Pema"         # ... Pema who?
        yield @pema.send "Just Pema"    # ... lol
        yield @nima.send "Just Nima"    # ... lol
        pretend.messages.should.eql [
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "@nima Who's there?" ]
          [ 'pema',   "knock knock" ]
          [ 'hubot',  "@pema Who's there?" ]
          [ 'nima',   "Nima" ]
          [ 'hubot',  "@nima Nima who?" ]
          [ 'pema',   "Pema" ]
          [ 'hubot',  "@pema Pema who?" ]
          [ 'pema',   "Just Pema" ]
          [ 'hubot',  "@pema lol" ]
          [ 'nima',   "Just Nima" ]
          [ 'hubot',  "@nima lol" ]
        ]

  context 'knock and enter test - directed user scene', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-and-enter-user.coffee'
      pretend.log.level = 'silent'
      @director = pretend.user 'director'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'

    context 'Nima gets whitelisted, both try to enter', ->

      it 'allows Nima', -> co =>
        yield @director.send "allow nima"
        yield @nima.send "knock knock"
        yield wait 20
        pretend.messages.should.eql [
          [ 'director', "allow nima" ]
          [ 'nima',     "knock knock" ]
          [ 'hubot',    "@nima You may enter!" ]
        ]

      it 'gives others default response', -> co =>
        yield @director.send "allow nima"
        yield @pema.send "knock knock"
        yield wait 20
        pretend.messages.should.eql [
          [ 'director', "allow nima" ]
          [ 'pema',     "knock knock" ]
          [ 'hubot',    "@pema Sorry, nima's only." ]
        ]

    context 'Nima is blacklisted user, both try to enter', ->

      it 'allows any but Nima', -> co =>
        yield @director.send "deny nima"
        yield @pema.send "knock knock"
        yield wait 20
        pretend.messages.should.eql [
          [ 'director', "deny nima" ]
          [ 'pema',   "knock knock" ]
          [ 'hubot',  "@pema You may enter!" ]
        ]

      it 'gives others default response', -> co =>
        yield @director.send "deny nima"
        yield @nima.send "knock knock"
        yield wait 20
        pretend.messages.should.eql [
          [ 'director', "deny nima" ]
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "@nima Sorry, no nima's." ]
        ]

  context 'knock and enter test - directed room scene', ->

    beforeEach ->
      pretend.start().read 'scripts/knock-and-enter-room.coffee'
      pretend.log.level = 'silent'
      @director = pretend.user 'director'
      @nima = pretend.user 'nima'
      @pema = pretend.user 'pema'
      @A = pretend.room '#A'
      @B = pretend.room '#B'

    context 'Room #A is whitelisted, nima and pema try to enter in both', ->

      it 'allows any in room #A', -> co =>
        yield @A.receive @director, "allow #A"
        yield @A.receive @pema, "knock knock"
        yield wait 10
        yield @A.receive @nima, "knock knock"
        yield wait 10
        @A.messages().should.eql [
          [ 'director',  "allow #A" ]
          [ 'pema',     "knock knock" ]
          [ 'hubot',    "@pema You may enter!" ]
          [ 'nima',     "knock knock" ]
          [ 'hubot',    "@nima You may enter!" ]
        ]

      it 'sends default response to other rooms', -> co =>
        yield @A.receive @director, "allow #A"
        yield @B.receive @pema, "knock knock"
        yield wait 10
        yield @B.receive @nima, "knock knock"
        yield wait 10
        @B.messages().should.eql [
          [ 'pema',   "knock knock" ]
          [ 'hubot',  "@pema Sorry, #A users only." ]
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "@nima Sorry, #A users only." ]
        ]

    context 'Room #A is blacklisted, nima and pema try to enter in both', ->

      it 'allows any in room #A', -> co =>
        yield @A.receive @director, "deny #A"
        yield @A.receive @pema, "knock knock"
        yield wait 10
        yield @A.receive @nima, "knock knock"
        yield wait 10
        @A.messages().should.eql [
          [ 'director',  "deny #A" ]
          [ 'pema',   "knock knock" ]
          [ 'hubot',  "@pema Sorry, no #A users." ]
          [ 'nima',   "knock knock" ]
          [ 'hubot',  "@nima Sorry, no #A users." ]
        ]

      it 'sends default response to other rooms', -> co =>
        yield @A.receive @director, "deny #A"
        yield @B.receive @pema, "knock knock"
        yield wait 10
        yield @B.receive @nima, "knock knock"
        yield wait 10
        @B.messages().should.eql [
          [ 'pema',     "knock knock" ]
          [ 'hubot',    "@pema You may enter!" ]
          [ 'nima',     "knock knock" ]
          [ 'hubot',    "@nima You may enter!" ]
        ]

###
e.g. transcript diagnostics for scene timeouts, to determine common causes
- using key, returns series of users and their last message before timeout occur
- demonstrates with non-default types
###
