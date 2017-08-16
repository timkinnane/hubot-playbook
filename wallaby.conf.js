module.exports = function (wallaby) {
  return {
    files: [ 'src/**/*.js' ],
    tests: [ 'test/**/*_test.coffee' ],
    compilers: { '**/*.js': wallaby.compilers.babel() }
  }
}
