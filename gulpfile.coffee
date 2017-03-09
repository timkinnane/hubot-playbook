'use strict'

gulp = require 'gulp'
$ = (require 'gulp-load-plugins') lazy: false
del = require 'del'
es = require 'event-stream'
minimist = require 'minimist'
boolifyString = require 'boolify-string'

paths =
  lint: [
    './gulpfile.coffee'
    './src/**/*.coffee'
  ]
  watch: [
    './gulpfile.coffee'
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
  paths.tests = ["./test/unit/**/*#{ options.modules }*.coffee"]
console.log paths.tests

gulp.task 'lint', ->
  gulp.src paths.lint
  .pipe $.coffeelint()
  .pipe $.coffeelint.reporter()
  .pipe $.coffeelint.reporter 'fail'

gulp.task 'clean', ['lint'], del.bind null, ['./coverage']

gulp.task 'coverage', ['clean'], (done) ->
  gulp.src paths.source
  .pipe $.coffeeIstanbul includeUntested: true
  .pipe $.coffeeIstanbul.hookRequire()
  .on 'finish', ->
    gulp.src paths.tests, cwd: __dirname
      .pipe $.if(!boolifyString(process.env.CI), $.plumber())
      .pipe $.mocha()
      .pipe $.coffeeIstanbul.writeReports({ dir: './coverage' })
      .on 'finish', ->
        process.chdir __dirname
        done()
  undefined

gulp.task 'watch', ['test'], -> gulp.watch paths.watch, ['test']

gulp.task 'test', ['coverage']

gulp.task 'default', ['test']
