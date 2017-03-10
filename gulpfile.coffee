'use strict'

gulp = require 'gulp'
$ = (require 'gulp-load-plugins') lazy: false
del = require 'del'
minimist = require 'minimist'
boolifyString = require 'boolify-string'

paths =
  lint: [
    './src/**/*.coffee'
  ]
  watch: [
    './src/**/*.coffee'
    './test/**/*.coffee'
    '!test/{temp,temp/**}'
  ]
  tests: [
    './test/unit/**/*.coffee'
    '!test/{temp,temp/**}'
  ]
  source: [
    './src/**/*.coffee'
  ]

# process command line options for running limited module tests
knownOptions = string: 'modules', default: modules: 'all'
options = minimist process.argv.slice(2), knownOptions
if options.modules isnt 'all'
  paths.source = ["./src/**/*#{ options.modules }*.coffee"]
  paths.tests[0] = "./test/unit/**/*#{ options.modules }*.coffee"

gulp.task 'lint', ->
  gulp.src paths.lint
    .pipe $.coffeelint()
    .pipe $.coffeelint.reporter()

gulp.task 'clean', del.bind null, ['./coverage']

gulp.task 'coverage', ['clean'], (done) ->
  gulp.src paths.source
    .pipe $.coffeeIstanbul includeUntested: true
    .pipe $.coffeeIstanbul.hookRequire()
    .on 'finish', ->
      gulp.src paths.tests, cwd: __dirname
        .pipe $.if !boolifyString(process.env.CI), $.plumber()
        .pipe $.mocha
          reporter: 'landing'
          bail: true
          compilers: 'coffee:coffee-script/register'
          require: 'coffee-coverage/register-istanbul'
        .pipe $.coffeeIstanbul.writeReports dir: './coverage'
        .on 'finish', ->
          process.chdir __dirname
          done()
  return

gulp.task 'watch', ['test'], ->
  gulp.watch paths.watch, ['test']

gulp.task 'test', ['lint', 'coverage']

gulp.task 'default', ['test']
