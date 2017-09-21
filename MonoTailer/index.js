'use strict';
var glob = require("glob")
var fs = require('fs');
var ts = require('tail-stream');
var nodeCleanup = require('node-cleanup');
var Parser = require('./parser');
var Restart = require('./restart');

var express = require('express');
var app = express();

var RestartSeconds = parseInt(process.env.RESTART_SECONDS || 180);

var tails = {};
var stats = {};

var globWorkerLogs = function(callback) {
  glob("/var/www/Monocle-*/shared/logs/worker.log", {
    nosort: true,
  }, function (er, files) {
    callback(er, files);
  });
};

var tailWorkerLog = function(f) {
  if (tails[f]) {
    var tail = tails[f];
    tail.end();
    delete tails[f];
  }

  var tail = ts.createReadStream(f, {
    beginAt: 'end',
    onTruncate: 'end',
    onMove: 'end',
    endOnError: 'true',
  });

  tails[f] = tail;
      

  var port = parseInt(f.match(/Monocle-(\d+)/)[1]);
  var sid = port - 10000;

  console.log('Tailing %s', f, port, sid);

  Parser.initSid(sid);

  tail.on("data", function(data) {
    if (data) {
      var str = data.toString('utf8').trim().split('\n');
      str.forEach(function(str) {
        //console.log('#%d data: %s', sid, str);
        Parser.parse(str, sid);
      });
    }
  });

  tail.on('end', function() {
    Parser.deinitSid(sid);
    delete tails[f];
  });

  tail.on('error', function(error) {
    console.log('ERROR: ', error);
    delete tails[f];
  });
};

var setupTailers = function() {
  globWorkerLogs(function(err, files) {
    if (err) {
      console.log("glob error", err);
    } else {
      files.forEach(function(f){
        if (!tails[f]) {
          tailWorkerLog(f);
        }
      });
    }
  });
};

var refreshInterval = setInterval(function() {
  setupTailers();
},5000);

setupTailers();

setInterval(function() {
  stats = Parser.stats();

  var deadProcesses = stats.deadProcesses;
  for (var sid in deadProcesses) {
    var lastAlive = deadProcesses[sid];
    if (lastAlive < (Date.now() - (RestartSeconds * 1000))) {
      Parser.deinitSid(sid);
      Parser.initSid(sid);
      Restart.restartMonocle(sid, function(err, o) {
        if (err) {
          console.log(err);
        }
      });
    }
  }
}, 10 * 1000);

nodeCleanup(function(exitCode, signal) {
  console.log('Exit', exitCode, signal);
  if (signal === 'SIGINT') {
    console.log('Doing cleaning up...');

    clearInterval(refreshInterval);

    for (var key in tails) {
      tails[key].end();
    }

    console.log(Parser.stats());

    console.log('Clean up done.');

    process.kill(process.pid, signal);
    nodeCleanup.uninstall();
    return false;
  }
});

app.get('/processes.json', function (req, res) {
  console.log('Serving /processes.json');
  res.send({
    deadProcesses: stats.deadProcesses,
    processes: stats.processStats,
  });
});

app.get('/accounts.json', function (req, res) {
  console.log('Serving /accounts.json');
  res.send({
    accountErrors: stats.accountErrors,
  });
});

app.listen(5589, function () {
  console.log('API server starting at %s:%d', 'http://0.0.0.0', 5589);
});
