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
knownOptions =
  string: ['modules','reporter']
  default:
    module: null
    reporter: 'landing'

options = minimist process.argv.slice(2), knownOptions
if options.modules?
  paths.source = ["./src/**/*#{ options.modules }*.coffee"]
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
    .pipe $.coffeeIstanbul.writeReports dir: './coverage'
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

###
  CLI tasks for development
  - `gulp test` to run tests once for debugging known issues
  - `gulp watch` while developing, to see tests in console
  - `gulp watch --modules {name}` for quicker tests of single module
  - `gulp watch --reporter {name}`
  - `gulp watch --modules Scene --reporter spec` example of above combined
  - `gulp docs` to review generated docs (skips running tests)
  - `gulp watch:docs` while documenting code, to auto-refresh docs on edit
  - `gulp watch:docs` before publishing,
  - `gulp publish` to publish a completed version or patch -- TODO: this
  # TODO: add to README.md
###

gulp.task 'test', test
gulp.task 'watch', watch
gulp.task 'docs', docs
gulp.task 'watch:docs', watchDocs
gulp.task 'default', test
