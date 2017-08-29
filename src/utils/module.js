'use strict'

import Base from '../modules/base'

class Module extends Base {
  constructor (robot, ...args) {
    super('module', robot, ...args)
  }
}

export default Module
