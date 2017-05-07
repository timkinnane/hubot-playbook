'use strict'

gulp = require 'gulp'
$ = (require 'gulp-load-plugins') lazy: false
del = require 'del'
minimist = require 'minimist'
boolifyString = require 'boolify-string'

paths =
  lint: [
    './src/**/*.coffee'
    './test/**/*.coffee'
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
knownOptions =
  string: ['modules','reporter']
  default:
    modules: null
    reporter: 'landing'

options = minimist process.argv.slice(2), knownOptions
if options.modules?
  paths.tests[0] = "./test/unit/**/*#{ options.modules }*.coffee"

gulp.task 'lint', ->
  gulp.src paths.lint,
    since: gulp.lastRun 'lint'
  .pipe $.coffeelint()
  .pipe $.coffeelint.reporter()

gulp.task 'clean:coverage', -> del ['coverage']

gulp.task 'coverage', (done) ->
  gulp.src paths.source, since: gulp.lastRun 'coverage'
  .pipe $.coffeeIstanbul includeUntested: true
  .pipe $.coffeeIstanbul.hookRequire()
  .on 'finish', ->
    gulp.src paths.tests, cwd: __dirname
    .pipe $.if !boolifyString(process.env.CI), $.plumber()
    .pipe $.mocha
      reporter: options.reporter
      bail: true
      compilers: 'coffee:coffee-script/register'
      require: 'coffee-coverage/register-istanbul'
    .pipe $.if options.modules is null, $.coffeeIstanbul.writeReports
      dir: './coverage'
    .on 'finish', done
  return

gulp.task 'clean:docs', -> del ['docs']

gulp.task 'docs:source', ->
  gulp.src paths.source.concat(['README.md']),
    base: '.'
    since: gulp.lastRun 'docs:source'
  .pipe $.docco layout: 'linear'
  .pipe gulp.dest 'docs'

gulp.task 'docs:coverage', (done) ->
  gulp.src paths.tests,
    cwd: __dirname
    since: gulp.lastRun 'docs:coverage'
  .pipe $.coffeeIstanbul.writeReports
    dir: './docs/coverage'
    reporters: [ 'json', 'text', 'text-summary', 'html' ]
  .on 'finish', done
  return

# build chains - used by CLI tasks
test = gulp.series 'lint', 'clean:coverage', 'coverage'
watch = gulp.series test, -> gulp.watch paths.watch, test
docs = gulp.series 'lint', 'clean:docs', gulp.parallel 'docs:coverage', 'docs:source'
watchDocs = gulp.series docs, -> gulp.watch paths.watch, docs
publish = gulp.series docs

gulp.task 'test', test
gulp.task 'watch', watch
gulp.task 'docs', docs
gulp.task 'watch:docs', watchDocs
gulp.task 'default', test
