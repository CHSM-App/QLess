#!/usr/bin/env node

/**
 * Module dependencies.
 */

require('dotenv').config();
var app = require('../app');
var debug = require('debug')('donotwait:server');
var http = require('http');
var db = require('../routes/db');
var log = require('../routes/middleware/logger');

/**
 * Get port from environment and store in Express.
 */

var port = normalizePort(process.env.PORT || '3000');
app.set('port', port);

/**
 * Create HTTP server.
 */

var server = http.createServer(app);

/**
 * Wait for the DB pool to be ready before accepting requests, otherwise the
 * first N requests after cold start race the pool and 500.
 */

db.ready()
  .then(function () {
    server.listen(port);
    server.on('error', onError);
    server.on('listening', onListening);
  })
  .catch(function (err) {
    log.error('Startup failed: DB not reachable: ' + err.message);
    process.exit(1);
  });

/**
 * Last-resort process-level handlers. An unhandled rejection won't crash the
 * worker silently; an uncaught exception logs and exits so a supervisor
 * (IIS/PM2/systemd) can restart cleanly.
 */
process.on('unhandledRejection', function (reason) {
  log.error('UNHANDLED REJECTION: ' + (reason && reason.stack ? reason.stack : reason));
});
process.on('uncaughtException', function (err) {
  log.error('UNCAUGHT EXCEPTION: ' + err.stack);
  process.exit(1);
});

/**
 * Normalize a port into a number, string, or false.
 */

function normalizePort(val) {
  var port = parseInt(val, 10);

  if (isNaN(port)) {
    // named pipe
    return val;
  }

  if (port >= 0) {
    // port number
    return port;
  }

  return false;
}

/**
 * Event listener for HTTP server "error" event.
 */

function onError(error) {
  if (error.syscall !== 'listen') {
    throw error;
  }

  var bind = typeof port === 'string'
    ? 'Pipe ' + port
    : 'Port ' + port;

  // handle specific listen errors with friendly messages
  switch (error.code) {
    case 'EACCES':
      log.error(bind + ' requires elevated privileges');
      process.exit(1);
      break;
    case 'EADDRINUSE':
      log.error(bind + ' is already in use');
      process.exit(1);
      break;
    default:
      throw error;
  }
}

/**
 * Event listener for HTTP server "listening" event.
 */

function onListening() {
  var addr = server.address();
  var bind = typeof addr === 'string'
    ? 'pipe ' + addr
    : 'port ' + addr.port;
  debug('Listening on ' + bind);
  log.info('Listening on ' + bind);
}
