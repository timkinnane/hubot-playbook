'use strict'

const async = require('async')

class Middleware {
  constructor (instance) {
    this.instance = instance // for writing logs, errors
    this.stack = []
  }

  /**
   * Execute all middleware in order and call 'next' with the latest 'done'
   * callback if last middleware calls through. If all middleware is compliant,
   * 'done' should be called with no arguments when the entire round trip is
   * complete.
   *
   * @param  {Object}   context Passed through the middleware stack
   * @param  {Function} next    Called when all middleware is complete
   * @param  {Function} [done]  Initial (final) completion callback.
   *                            May be wrapped by executed middleware.
   * @return {Promise}          Resolves with context when middleware completes
   */
  execute (context, next, done) {
    return new Promise((resolve, reject) => {
      const self = this

      // If none provided, needs something to do finally
      if (done == null) done = function () {}

      // Allow each middleware to resolve the promise early if it calls done()
      const pieceDone = () => {
        resolve(done(context))
      }

      // Execute a single piece of middleware and update the completion callback
      // (each piece of middleware can wrap the 'done' callback with additional
      // logic).
      function executeSingleMiddleware (doneFunc, middlewareFunc, cb) {
        // Match the async.reduce interface
        function nextFunc (newDoneFunc) {
          cb(null, newDoneFunc || doneFunc)
        }

        // Catch errors in synchronous middleware
        try {
          middlewareFunc(context, nextFunc, doneFunc)
        } catch (err) {
          // Maintaining the existing error interface (Response object)
          self.instance.emit('error', err, context.response)
          // Forcibly fail the middleware and stop executing deeper
          doneFunc()
          err.context = context
          reject(err)
        }
      }

      // Executed when the middleware stack is finished
      function allDone (_, finalDoneFunc) {
        resolve(next(context, finalDoneFunc))
      }

      // Execute each piece of middleware, collecting the latest 'done' callback
      // at each step.
      process.nextTick(async.reduce.bind(null, this.stack, pieceDone, executeSingleMiddleware, allDone))
    })
  }

  /**
   * Add a function to the middleware stack, to either continue or interrupt the
   * pipeline. Called with:
   * - bound 'this' containing the executing instance
   * - context, object containing relevant attributes for the pipeline
   * - next, function to call to continue the pipeline
   * - done, final pipeline function, optionally given as argument to next
   *
   * Call next to continue on to the next piece of middleware/execute. Call with
   * no argument or with a single, optional argument: either the provided done
   * function or a new function that eventually calls done.
   *
   * Call done to interrupt middleware execution and begin executing the chain
   * of completion functions.
   *
   * @param  {Function} piece Pipeline function to add to the stack.
   */
  register (piece) {
    if (piece.length !== 3) {
      throw new Error(`Incorrect number of arguments for middleware callback (expected 3, got ${piece.length})`)
    }
    this.stack.push(piece)
  }
}

module.exports = Middleware
