_ = require 'lodash'
Playbook = require '../src/Playbook'

###
TODO:
  Make these and others run as a hubot script in docs page, demonstrating
  - a single example defined using dialogue directly, scene, then playbook
  - usage examples for director, transcript and outline
  - using listener ID to populate data for template tags
  - rate limiting to mimic thinking and conversation pace
  - http requests and payloads, for messenger buttons and menus
  - NLP through Wit.ai or Google or Microsoft
###

module.exports = (robot) ->

  pb = new Playbook robot
	soloScene = pb.scene 'user'
	groupScene = pb.scene 'room'
	locationScene = pb.scene 'userRoom'

	robot.hear /play/, (res) ->
		dialogue = groupScene.enter res, "OK, I'm it! MARCO!"
		marcoPolo = (res) ->
			if Math.floor(Math.random() * 6) + 1 < 6
				dialogue.choice /polo/i, "MARCO!", (res) -> marcoPolo res
			else
				res.reply "I got you!"
		marcoPolo res

	robot.respond /clean the house/, (res) ->
		dialogue = soloScene.enter res, 'Sure, where should I start? [Kitchen] or [Bathroom]'
		dialogue.choice /kitchen/i, 'On it boss!'
		dialogue.choice /bathroom/i, 'Do I really have to?', () ->
			dialogue.choice /yes/, 'Ugh, fine!'

	robot.hear /jump/, (res) ->
		dialogue = locationScene.enter res, 'Sure, How many times?'
		dialogue.choice /([0-9]+)/i, (res) ->
			times = parseInt res.match[1], 10
			res.emote 'Jumps' for [0...times]

	robot.respond /.*the mission/, (res) ->
		res.reply 'Your have 5 seconds to accept your mission, or this message will self-destruct'
		dialogue = soloScene.enter res,
			timeout: 5000 # 5 second timeout
		# overrride timeout method
		dialogue.onTimeout = (res) ->
			res.emote ":bomb: Boom!"
		dialogue.choice /yes/i, 'Great! Here are the details...'

	robot.respond /whos talking/i, (res) ->
		soloParticipants = _.keys soloScene.engaged
		groupParticipants = _.keys groupScene.engaged
		locationParticipants = _.keys locationScene.engaged
		IDs = _.union soloParticipants, groupParticipants, locationParticipants
		if IDs.length
			res.reply "im in dialogue with these IDs: #{ IDs.join ', ' }"
		else
			res.reply "nobody right now"
