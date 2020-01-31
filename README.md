# CloudWatch Slack Alarm

Use this script to easily create slack alerts for cloudwatch alarms.

Prereqs:
- python
- make
- aws-cli

### Configuring aws-cli
   aws configure

### Create Incoming WebHook for Slack Channel
Make sure you have added the incoming-webhooks integrations for your slack
channel. Go to your channel, click the gear icon and choose "Add an app". Type
"incoming" into the search filter and choose "Incoming WebHooks". Once the
webhook is created save the webhook url somewhere safe.

### Create Slack Alert for CloudWatch Alarm
```
CHANNEL_NAME=<your_channel_name> WEBHOOK_URL=<your_webhook_url> ALARM_NAME=<your_alarm_name> make
```
