package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
)

type Request struct {
	Records []struct {
		SNS struct {
			Type       string `json:"Type"`
			Timestamp  string `json:"Timestamp"`
			SNSMessage string `json:"Message"`
		} `json:"Sns"`
	} `json:"Records"`
}

type SNSMessage struct {
	AlarmName      string `json:"AlarmName"`
	NewStateValue  string `json:"NewStateValue"`
	NewStateReason string `json:"NewStateReason"`
}

type Attachment struct {
	Text  string `json:"text"`
	Color string `json:"color"`
	Title string `json:"title"`
}

type SlackMessage struct {
	Text        string       `json:"text"`
	Attachments []Attachment `json:"attachments"`
}

var WebHookURL = os.Getenv("WEBHOOK_URL")

func parseMessage(r Request) (*SNSMessage, error) {
	var snsMessage SNSMessage
	err := json.Unmarshal([]byte(r.Records[0].SNS.SNSMessage), &snsMessage)
	if err != nil {
		return nil, err
	}

	return &snsMessage, nil
}

func getAttachmentColor(stateValue string) string {
	switch strings.ToLower(stateValue) {
	case "alarm":
		return "danger"
	case "ok":
		return "good"
	default:
		return "good"
	}
}

func buildSlackMessage(message *SNSMessage) SlackMessage {
	return SlackMessage{
		Text: fmt.Sprintf("`%s`", message.AlarmName),
		Attachments: []Attachment{
			Attachment{
				Text:  fmt.Sprintf("`%s`", message.NewStateReason),
				Color: getAttachmentColor(message.NewStateValue),
				Title: "Reason",
			},
		},
	}
}

func postToSlack(message SlackMessage) error {
	client := &http.Client{}
	data, err := json.Marshal(message)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", WebHookURL, bytes.NewBuffer(data))
	if err != nil {
		return err
	}

	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		fmt.Println(resp.StatusCode)
		return err
	}

	return nil
}

func slackHandler(request Request) error {
	message, err := parseMessage(request)
	if err != nil {
		log.Printf("Failed to parse incoming request: %s", err.Error())
		return err
	}
	log.Printf("New alarm: %s - Reason: %s\n", message.AlarmName, message.NewStateReason)

	slackMessage := buildSlackMessage(message)

	err = postToSlack(slackMessage)
	if err != nil {
		log.Printf("Failed to post to slack: %s\n", err.Error())
		return err
	}

	log.Println("Notification has been sent")
	return nil
}

func main() {
	lambda.Start(slackHandler)
}
