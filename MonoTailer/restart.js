'use strict';
var ps = require("ps-node");
var fs = require("fs");
var exec = require("child_process").exec;
var Slack = require('./slack');

var deleteSock = function(port, callback) {
  var file = "/var/www/Monocle-"+port+"/current/monocle.sock";
  console.log("Deleteing sock at: %s", file);
  var perms = fs.constants.R_OK | fs.constants.W_OK;
  fs.access(file, perms, function(err) {
    if (err) {
      callback();
    } else {
      fs.unlink(file, callback);
    }
  });
};

var cleanupProcess = function(port, callback) {
  console.log("Cleaning up port: %d", port);

  ps.lookup({
    command: 'python3',
    arguments: '--signature='+port,
  }, function(err, resultList) {
    if (err) {
      console.log("Cleanup process error",err);
      callback();
    } else {
      resultList.forEach(function(prc){
        if( prc ){
          console.log( 'PID: %s, COMMAND: %s, ARGUMENTS: %s', prc.pid, prc.command, prc.arguments );
          ps.kill( prc.pid, function(err) {
            if (err) {
            } else {
              console.log('Process %s has been killed!', prc.pid);
            }
          });
        }
      });

      setTimeout(function() {
        deleteSock(port, function() {
          callback();
        });
      }, 5000);
    }
  });
};

var shutdownSv = function(svid, callback) {
  console.log("Shutting down svid: %s", svid);
  exec("supervisorctl stop "+svid, function(e) {
    callback();
  });
};

var startupSv = function(svid, callback) {
  console.log("Starting up svid: %s", svid);
  exec("supervisorctl start "+svid, function(e) {
    callback();
  });
};

var restartMonocle = function(sid, callback) {
  callback = callback || function(){};
  var svid;
  console.log("Getting svid for sid: %d", sid);
  exec("supervisorctl status | grep -E '_"+sid+"\\s+(EXITED|FATAL|RUNNING)'", function(e,stdout){
    if (e) {
      if (e.code === 1) {
        console.log("Command failed: %s", e.cmd);
      } else {
        console.log("Unknown error", e);
      }
      callback(e);

    } else if (svid = stdout.split(" ")[0]) {
      console.log("Svid acquired for sid: %d, svid: %s", sid, svid);

      shutdownSv(svid, function() {
        var port = parseInt(sid) + 10000;
        cleanupProcess(port, function() {
          startupSv(svid, function() {
            console.log("Restarted sid: %d, svid: %s", sid, svid);

            Slack.sendSlack("Dead process restarted for sid: " + sid + " svid: " + svid)

            callback(null, {
              sid: sid,
              svid: svid,
            });
          });
        });
      });
    }
  });
};

module.exports.cleanupProcess = cleanupProcess;
module.exports.restartMonocle = restartMonocle;
