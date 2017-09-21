'use strict';

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

var async = require('async');

var Middleware = function () {
  function Middleware(instance) {
    _classCallCheck(this, Middleware);

    this.instance = instance; // for writing logs, errors
    this.stack = [];
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


  _createClass(Middleware, [{
    key: 'execute',
    value: function execute(context, next, done) {
      var _this = this;

      return new Promise(function (resolve, reject) {
        var self = _this;

        // If none provided, needs something to do finally
        if (done == null) done = function done() {};

        // Allow each middleware to resolve the promise early if it calls done()
        var pieceDone = function pieceDone() {
          resolve(done(context));
        };

        // Execute a single piece of middleware and update the completion callback
        // (each piece of middleware can wrap the 'done' callback with additional
        // logic).
        function executeSingleMiddleware(doneFunc, middlewareFunc, cb) {
          // Match the async.reduce interface
          function nextFunc(newDoneFunc) {
            cb(null, newDoneFunc || doneFunc);
          }

          // Catch errors in synchronous middleware
          try {
            middlewareFunc(context, nextFunc, doneFunc);
          } catch (err) {
            // Maintaining the existing error interface (Response object)
            self.instance.emit('error', err, context.response);
            // Forcibly fail the middleware and stop executing deeper
            doneFunc();
            err.context = context;
            reject(err);
          }
        }

        // Executed when the middleware stack is finished
        function allDone(_, finalDoneFunc) {
          resolve(next(context, finalDoneFunc));
        }

        // Execute each piece of middleware, collecting the latest 'done' callback
        // at each step.
        process.nextTick(async.reduce.bind(null, _this.stack, pieceDone, executeSingleMiddleware, allDone));
      });
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

  }, {
    key: 'register',
    value: function register(piece) {
      if (piece.length !== 3) {
        throw new Error('Incorrect number of arguments for middleware callback (expected 3, got ' + piece.length + ')');
      }
      this.stack.push(piece);
    }
  }]);

  return Middleware;
}();

module.exports = Middleware;
//# sourceMappingURL=middleware.js.map