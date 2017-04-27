# TODO: module attributes:
# - username/roomAuth: if given, creates lambda for Director authorise method
# e.g.
# if usernameAuth? or roomAuth?
#   authorise = (username, room, res) =>
#     if usernameAuth?
#       if @robot.adapter.callMethod usernameAuth, username, res.message.user.name
#         return true
#     if roomAuth?
#       if @robot.adapter.callMethod roomAuth, username, res.message.user.name
#         return true
#     return false
