'use strict';

String.prototype.toRegExp = function () {
  // eslint-disable-line
  if (this === undefined || this === '') return;
  var match = this.match(new RegExp('^/(.+)/(.*)$'));
  if (match) return new RegExp(match[1], match[2]);
};
//# sourceMappingURL=string-to-regex.js.map