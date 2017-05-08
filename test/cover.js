var coffeeCoverage = require('coffee-coverage');
var coverageVar = coffeeCoverage.findIstanbulVariable();

coffeeCoverage.register({
  instrumentor: 'istanbul',
  basePath: process.cwd(),
  exclude: ['/test', '/node_modules', '/.git', '/scripts', '/docs'],
  coverageVar: coverageVar,
  writeOnExit: 'coverage/coverage-coffee.json',
  initAll: false
});
