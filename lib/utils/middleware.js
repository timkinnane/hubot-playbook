'use strict'

const async = require('async')

/**
 * Middleware manages a stack of function pieces to execute in a pipeline.
 *
 * It is a generic utility class that can be invoked in any logic that needs to
 * allow interruption or manipulation of context by external functions.
 *
 * @param {Object} instance     Module instance for writing logs, errors
 */
class Middleware {
  constructor (instance) {
    this.instance = instance
    this.stack = []
  }

  /**
   * Execute all middleware in order and call `next` with the latest `done`
   * callback if each piece continued by calling their own respective `done`.
   *
   * Each piece of middleware can wrap the `done` callback with additional
   * logic.
   *
   * @param  {object}   context Passed through the stack, usually contains
   *                            response and any other relevant attributes
   * @param  {Function} next    Called when all middleware is complete
   * @param  {Function} done    Initial (final) completion callback
   * @return {Promise}          Resolves with final context when middleware
   *                            completes (before completion callback)
   */
  execute (context, next, done) {
    return new Promise((resolve, reject) => {
      if (done == null) done = function () {}

      // Async reduce `memo`, given to each piece as last argument `done`
      // Can be called to interrupt execution of the stack.
      const pieceDone = () => {
        reject(new Error('Middleware piece called done'))
        done(context)
      }

      // Async reduce `iteratee`, invoked with reduce `memo, item, callback`.
      // Executes each piece and updates the completion callback.
      function doPiece (doneFunc, middlewareFunc, cb) {
        const nextFunc = (newDoneFunc) => cb(null, newDoneFunc || doneFunc)

        // Catch errors in synchronous middleware
        try {
          middlewareFunc(context, nextFunc, doneFunc)
        } catch (err) {
          // Maintaining the existing error interface (Response object)
          this.instance.emit('error', err, context.response)
          // Forcibly fail the middleware and stop executing deeper
          doneFunc()
          err.context = context
          reject(err)
        }
      }

      // Async reduce `callback`, called when the whole stack is finished.
      const allDone = (_, finalDoneFunc) => {
        resolve(context)
        next(context, finalDoneFunc)
      }

      // async reduce middleware stack
      reduceStack(this.stack, pieceDone, doPiece.bind(this), allDone)
    })
  }

  /**
   * Registers a new middleware piece.
   *
   * Pieces are generic functions that can either continue or interrupt the
   * execution of subsequent pieces in the stack. Each function is called with
   * `context, next, done`. To continue execution, each piece should call `next`
   * function with `done` as an optional argument.
   *
   * Call next to continue on to the next piece of middleware/execute. Call with
   * no argument or with a single, optional argument: either the provided done
   * function or a new function that eventually calls done.
   *
   * To interrupt, the function should call `done` with no arguments.
   *
   * @param  {Function} piece Pipeline function to add to the stack
   */
  register (piece) {
    if (piece.length !== 3) {
      throw new Error(`Incorrect number of arguments for middleware callback (expected 3, got ${piece.length})`)
    }
    this.stack.push(piece)
  }
}

/**
 * Async reduce stack execution helper, abstracted for clear consistency with
 * parameters matching async package docs.
 *
 * Starts processing on nextTick at end of current node event loop.
 *
 * @param  {Iterable} coll       A collection to iterate over.
 * @param  {*}        memo       The initial state of the reduction.
 * @param  {Function} iteratee   Async function applied to each item in the
 *                               array to produce the next step in the
 *                               reduction. The iteratee should complete with
 *                               the next state of the reduction. If the
 *                               iteratee complete with an error, the reduction
 *                               is stopped and the main callback is immediately
 *                               called with the error.
 *                               Invoked with (memo, item, callback).
 * @param  {Function} [callback] A callback which is called after all the
 *                               iteratee functions have finished.
 *                               Result is the reduced value.
 *                               Invoked with (err, result).
 */
function reduceStack (coll, memo, iteratee, callback) {
  process.nextTick(async.reduce.bind(null, coll, memo, iteratee, callback))
}

module.exports = Middleware
