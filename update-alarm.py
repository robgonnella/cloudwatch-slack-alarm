import sys, json
import boto3

args = sys.argv[1:]
alarm_name = args[0]
topic_arn = args[1]

client = boto3.client('cloudwatch')
alarms = client.describe_alarms(AlarmNames=[alarm_name])['MetricAlarms']

if len(alarms) > 0:
    alarm = alarms[0]
    alarm['AlarmActions'].append(topic_arn)
    alarm['OKActions'].append(topic_arn)
    client.put_metric_alarm(
        AlarmName=alarm['AlarmName'],
        EvaluationPeriods=alarm['EvaluationPeriods'],
        ComparisonOperator=alarm['ComparisonOperator'],
        MetricName=alarm['MetricName'],
        Period=alarm['Period'],
        Namespace=alarm['Namespace'],
        Statistic=alarm['Statistic'],
        Threshold=alarm['Threshold'],
        OKActions=alarm['OKActions'],
        AlarmActions=alarm['AlarmActions']
    )
else:
    print("No alarms found for alarm name: %s" % alarm_name)
