'use strict'

const Base = require('../modules/base')

class Module extends Base {
  constructor (robot, ...args) {
    super('module', robot, ...args)
  }
}

module.exports = Module
