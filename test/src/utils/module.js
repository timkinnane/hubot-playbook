// Had to move this dummy module for testing Base method inheritance out of
// coffee-script, because it wasn't supporting extending the new es6 class.
import Base from '../../lib/modules/base'

class Module extends Base {
  constructor (robot, ...args) {
    super('module', robot, ...args)
    this.config.test = true
  }
}

export default Module
