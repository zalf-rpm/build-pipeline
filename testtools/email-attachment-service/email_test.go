package main

import (
	"testing"
)

func TestEmailClient_CheckForNewEmails(t *testing.T) {

	config, err := LoadConfig("test_config.yaml")
	if err != nil {
		t.Fatalf("failed to load config: %v", err)
	}
	testEmailClient := NewEmailClient(config)
	testEmailConfig := NewEmailConfig(config)
	type args struct {
		eConf *EmailConfig
	}
	tests := []struct {
		name    string
		ec      *EmailClient
		args    args
		wantErr bool
	}{
		{"valid email check", testEmailClient, args{eConf: testEmailConfig}, false},
		{"invalid email check", testEmailClient, args{eConf: &EmailConfig{}}, true},
		{"invalid email check", testEmailClient, args{eConf: &EmailConfig{From: "invalid"}}, true},
		{"invalid email check", testEmailClient, args{eConf: &EmailConfig{SharedFolder: "invalid"}}, true},
		{"invalid email check", testEmailClient, args{eConf: &EmailConfig{DownloadDir: "invalid"}}, true},
		{"invalid email check", testEmailClient, args{eConf: &EmailConfig{Subject: "invalid"}}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := tt.ec.CheckForNewEmails(tt.args.eConf); (err != nil) != tt.wantErr {
				t.Errorf("EmailClient.CheckForNewEmails() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestEmailClient_Connect(t *testing.T) {

	config, err := LoadConfig("test_config.yaml")
	if err != nil {
		t.Fatalf("failed to load config: %v", err)
	}
	testEmailClient := NewEmailClient(config)

	tests := []struct {
		name    string
		ec      *EmailClient
		wantErr bool
	}{
		{"valid connection", testEmailClient, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := tt.ec.Connect()
			if (err != nil) != tt.wantErr {
				t.Errorf("EmailClient.Connect() error = %v", err)
				return
			}
			if got == nil {
				t.Error("EmailClient.Connect() client nil, no error")
			}
		})
	}
}
