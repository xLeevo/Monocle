'use strict';

require('dotenv').config();
var express = require('express');
var app = express();
var bodyParser = require('body-parser');
var async =require('async');
var exec = require('child_process').exec;
var fs = require('fs');

var queue = async.queue(function(task, callback){
  var head = task;
  console.log("Deploying next: ", head.sn);

  var commands = [];
  var configFile;

  if (head.server_port && head.config_file) {
    configFile = '/tmp/monocle.config.'+head.server_port+'.py';
    fs.writeFileSync('/tmp/monocle.config.'+head.server_port+'.py', head.config_file);
  }

  if (head.sn) {
    commands.push(['SN',head.sn].join('='));
  }

  if (head.worker_name) {
    commands.push(['WORKER_NAME',head.worker_name].join('='));
  }

  if (head.server_host) {
    commands.push(['SERVER_HOST',head.server_host].join('='));
  }

  if (head.server_port) {
    commands.push(['SERVER_PORT',head.server_port].join('='));
  }

  if (head.bootstrap) {
    commands.push(['BOOTSTRAP',head.bootstrap].join('='));
  }

  if (head.no_pickle) {
    commands.push(['NO_PICKLE',head.no_pickle].join('='));
  }

  if (configFile) {
    commands.push(['CONFIG_FILE',configFile].join('='));
  }

  commands.push(['/usr/local/rbenv/shims/bundle exec cap production deploy']);


  var child = exec(commands.join(' '), {
    cwd: process.env.DEPLOY_CWD,
    uid: parseInt(process.env.DEPLOY_UID),
    gid: parseInt(process.env.DEPLOY_GID),
    stdio:[
      process.stdin,
      process.stdout,
      process.stderr,
    ],
  }, function(error, stdout, stderr) {
    if (!error) {
      fs.unlinkSync(configFile);
    }

    console.log('stdout: ', stdout);
    console.log('stderr: ', stderr);

    if (error !== null) {
      console.log('exec error: ', error);
    }

    setTimeout(function() {
      callback();
    }, 1000);

  });

  child.stdout.pipe(process.stdout);
  child.stderr.pipe(process.stderr);

}, 10);

app.use(bodyParser.urlencoded({ extended: true }));

app.get('/', function (req, res) {
  console.log('/');
  res.send({status:'Deployer active'});
});

app.post('/deploy', function (req, res) {
  var deployConfig = {
    sn: req.body.sn,
    worker_name: req.body.worker_name,
    server_host: req.body.server_host,
    server_port: parseInt(req.body.server_port),
    bootstrap: req.body.bootstrap,
    no_pickle: req.body.no_pickle,
    config_file: req.body.config_file,
  };

  console.log("Registering deploy: %s", deployConfig.worker_name);

  queue.push(deployConfig, function(err) {
    if (err) {
      console.log('Error during processing %s.', deployConfig.sn, err);
    } else {
      console.log('Finished processing %s.', deployConfig.sn);
    }
  });

  res.send({
    message: "Queuing deployer",
    config: deployConfig, 
  });
});

app.listen(5588, function () {
  console.log('Monocle deployer listening on port 5588')
});
