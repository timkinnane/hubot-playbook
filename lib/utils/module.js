'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _base = require('../modules/base');

var _base2 = _interopRequireDefault(_base);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

function _possibleConstructorReturn(self, call) { if (!self) { throw new ReferenceError("this hasn't been initialised - super() hasn't been called"); } return call && (typeof call === "object" || typeof call === "function") ? call : self; }

function _inherits(subClass, superClass) { if (typeof superClass !== "function" && superClass !== null) { throw new TypeError("Super expression must either be null or a function, not " + typeof superClass); } subClass.prototype = Object.create(superClass && superClass.prototype, { constructor: { value: subClass, enumerable: false, writable: true, configurable: true } }); if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass; }

var Module = function (_Base) {
  _inherits(Module, _Base);

  function Module(robot) {
    var _ref;

    _classCallCheck(this, Module);

    for (var _len = arguments.length, args = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
      args[_key - 1] = arguments[_key];
    }

    return _possibleConstructorReturn(this, (_ref = Module.__proto__ || Object.getPrototypeOf(Module)).call.apply(_ref, [this, 'module', robot].concat(args)));
  }

  return Module;
}(_base2.default);

exports.default = Module;
module.exports = exports['default'];
//# sourceMappingURL=module.js.map