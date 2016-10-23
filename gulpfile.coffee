'use strict'

gulp = require 'gulp'
$ = (require 'gulp-load-plugins') lazy: false
del = require 'del'
es = require 'event-stream'
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
    './test/**/*.coffee'
    '!test/{temp,temp/**}'
  ]
  source: [
    './src/**/*.coffee'
  ]

gulp.task 'lint', ->
  gulp.src paths.lint
    .pipe $.coffeelint('./coffeelint.json')
    .pipe $.coffeelint.reporter()

gulp.task 'clean', del.bind(null, ['./test/coverage'])

gulp.task 'istanbul', ['clean'], (cb) ->
  gulp.src ['./src/**/*.coffee']
    #Covering files
    .pipe $.coffeeIstanbul({ includeUntested: true })
    .pipe $.coffeeIstanbul.hookRequire()
    .on 'finish', ->
      gulp.src ['./test/**/*.coffee'], {cwd: __dirname}
        .pipe $.if(!boolifyString(process.env.CI), $.plumber())
        .pipe $.mocha()
        #Creating the reports after tests runned
        .pipe $.coffeeIstanbul.writeReports({ dir: './test/coverage' })
        .on 'finish', ->
          process.chdir __dirname
          cb()
  undefined

gulp.task 'watch', ['test'], ->
  gulp.watch paths.watch, ['test']

gulp.task 'default', ['test']
gulp.task 'test', ['lint', 'istanbul']
