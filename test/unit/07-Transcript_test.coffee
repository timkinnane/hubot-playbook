### copied from old Dialogue tests...

  describe '.record', ->

    beforeEach ->
      @match = sinon.spy()
      @mismatch = sinon.spy()
      @dialogue.on 'match', @match
      @dialogue.on 'mismatch', @mismatch
      @key = @dialogue.path
        prompt: 'Turn left or right?'
        branches: [
          [ /left/, 'Ok, going left!' ]
          [ /right/, 'Ok, going right!' ]
        ]
        key: 'which-way'
        error: 'Bzz. Left or right only!'

    context 'with arguments from the sent prompt', ->

      it 'adds match type, "bot" and content to transcript', ->
        @dialogue.paths[@key].transcript[0].should.eql [
          'send'
          'bot'
          'Turn left or right?'
        ]

    context 'with arguments from a matched choice', ->

      beforeEach ->
        @tester.send 'left'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'match'
          @rec.message.user
          'left'
        ]

      it 'emits mismatch event with user, content', ->
        @match.should.have.calledWith @rec.message.user, 'left'

    context 'with arguments from a mismatched choice', ->

      beforeEach ->
        @tester.send 'up'

      it 'adds match type, user and content to transcript', ->
        @dialogue.paths[@key].transcript[1].should.eql [
          'mismatch'
          @rec.message.user
          'up'
        ]

      it 'emits mismatch event with user, content', ->
        @mismatch.should.have.calledWith @rec.message.user, 'up'

###
