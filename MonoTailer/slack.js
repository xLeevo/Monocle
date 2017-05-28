'use strict';
var Slack = require('slack-node');
var SlackUrl = process.env.SLACK_URL;
var SlackChannel = process.env.SLACK_CHANNEL;
var slack = new Slack();
slack.setWebhook(SlackUrl);

var sendSlack = function(msg) {
  if (SlackUrl && SlackChannel) {
    slack.webhook({
      channel: SlackChannel,
      text: msg,
    }, function(err) {
      if (err) {
      } else {
        console.log("Slack message sent: %s", msg);
      }
    });
  }
};

module.exports.sendSlack = sendSlack;
