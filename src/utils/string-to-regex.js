
String.prototype.toRegExp = function() { // eslint-disable-line
  if (this === undefined || this === '') return
  let match = this.match(new RegExp('^/(.+)/(.*)$'))
  return match
    ? new RegExp(match[1], match[2])
    : new RegExp(this, 'i')
}
