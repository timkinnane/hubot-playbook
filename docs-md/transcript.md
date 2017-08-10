## Transcript

A transcripts records conversational events, including meta about the user,
message and module states. It is configurable to provide an overview or
drilled down analytics of specific interactions.

For reference, these are the event types and args used by Playbook and Hubot:
```
Robot
              error       Error
              running     -
Robot.brain
              loaded      data
              save        data
              close       -
Robot.adapter
              connected
```
```
Dialogue
              end         Dialogue, Response
              send        Dialogue, Response
              timeout     Dialogue, Response
              match       Dialogue, Response
              catch       Dialogue, Response
              mismatch    Dialogue, Response
Scene
              enter       Scene, Response, Dialogue
              exit        Scene, Response, status(complete|incomplete|timeout)
Director
              denied      Dialogue, Response
```

### Usage

TODO!
