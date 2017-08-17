'use strict';

// Had to move this dummy module for testing Base method inheritance out of
// coffee-script, because it wasn't supporting extending the new es6 class.
Object.defineProperty(exports, "__esModule", { value: true });var _base = require('../../lib/modules/base');var _base2 = _interopRequireDefault(_base);function _interopRequireDefault(obj) {return obj && obj.__esModule ? obj : { default: obj };}

class Module extends _base2.default {
  constructor(robot, ...args) {
    super('module', robot, ...args);
  }}exports.default =


Module;module.exports = exports['default'];