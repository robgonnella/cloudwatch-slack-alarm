account_id = $(shell aws sts get-caller-identity | python -c "import sys, json; print json.load(sys.stdin)['Account']")
executable = slack-notification
GOOS ?= linux

base_name = slack-$(CHANNEL_NAME)
role_name = $(base_name)-role
topic_name = $(base_name)-topic
lambda_function_name = $(base_name)-notifications

lambda_target = $(base_name)-lambda.json

define parse_json
	$(shell cat $(1) | python -c "import sys, json; print json.load(sys.stdin)$(2)")
endef

.PHONY: all update-cloudwatch-alarm

all: \
check-channel \
check-webhook \
check-alarm \
update-cloudwatch-alarm

check-channel:
ifndef CHANNEL_NAME
	$(error "You must set CHANNEL_NAME")
	exit 1
endif

check-webhook:
ifndef WEBHOOK_URL
	$(error "You must set WEBHOOK_URL")
	exit 1
endif

check-alarm:
ifndef ALARM_NAME
	$(error "You must set ALARM_NAME")
	exit 1
endif

$(executable): main.go
	GOOS=$(GOOS) CGO_ENABLED=false go build -ldflags '-s -w' -o $(executable)

$(executable).zip: $(executable)
	zip $(executable).zip $(executable)

topic.json:
	aws sns create-topic --name $(topic_name) > topic.json

lambda-role.json:
	aws iam create-role \
		--role-name $(role_name) \
		--assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": ["apigateway.amazonaws.com","lambda.amazonaws.com","events.amazonaws.com"]}, "Action": "sts:AssumeRole"}]}' \
		> lambda-role.json
	aws iam attach-role-policy \
		--role-name $(role_name) \
		--policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
	sleep 10

lambda-function.json: \
check-channel \
check-webhook \
$(executable).zip \
lambda-role.json
	role_arn="$(strip $(call parse_json,lambda-role.json,['Role']['Arn']))"; \
		aws lambda create-function \
			--role "$$role_arn" \
			--function-name $(lambda_function_name) \
			--runtime go1.x \
			--handler $(executable) \
			--description "Slack Notifications for $(CHANNEL_NAME)" \
			--environment Variables={WEBHOOK_URL=$(WEBHOOK_URL)} \
			--zip-file fileb://$(executable).zip \
			--publish > lambda-function.json
	aws lambda add-permission \
		--function-name $(lambda_function_name) \
		--action lambda:InvokeFunction \
		--statement-id sns \
		--principal sns.amazonaws.com

subscribe.json: topic.json lambda-function.json
	topic_arn="$(strip $(call parse_json,topic.json,['TopicArn']))"; \
	endpoint="$(strip $(call parse_json,lambda-function.json,['FunctionArn']))"; \
		aws sns subscribe \
			--topic-arn "$$topic_arn" \
			--protocol lambda \
			--notification-endpoint "$$endpoint" \
			--return-subscription-arn \
			> subscribe-alarm.json

update-cloudwatch-alarm: \
check-channel \
check-webhook \
check-alarm \
subscribe.json
	topic_arn="$(strip $(call parse_json,topic.json,['TopicArn']))"; \
		python ./update-alarm.py "$(ALARM_NAME)" "$$topic_arn"
