package main

import (
	"testing"
)

func TestEmailClient_CheckForNewEmails(t *testing.T) {

	config, err := LoadConfig("test_config_connect.yaml")
	if err != nil {
		t.Fatalf("failed to load config: %v", err)
	}
	// validate the config
	if err := config.Validate(); err != nil {
		t.Fatalf("failed to validate config: %v", err)
	}
	// create a new email client
	testEmailClient, err := NewEmailClient(config)
	if err != nil {
		t.Fatalf("failed to create email client: %v", err)
	}
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
		// {"invalid email check", testEmailClient, args{eConf: &EmailConfig{}}, true},
		// {"invalid email check", testEmailClient, args{eConf: &EmailConfig{From: "invalid"}}, true},
		// {"invalid email check", testEmailClient, args{eConf: &EmailConfig{SharedFolder: "invalid"}}, true},
		// {"invalid email check", testEmailClient, args{eConf: &EmailConfig{DownloadDir: "invalid"}}, true},
		// {"invalid email check", testEmailClient, args{eConf: &EmailConfig{Subject: "invalid"}}, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := tt.ec.CheckForNewEmails(tt.args.eConf, tt.args.eConf.Verbose); (err != nil) != tt.wantErr {
				t.Errorf("EmailClient.CheckForNewEmails() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestEmailClient_Connect(t *testing.T) {

	config, err := LoadConfig("test_config_connect.yaml")
	if err != nil {
		t.Fatalf("failed to load config: %v", err)
	}
	testEmailClient, err := NewEmailClient(config)
	if err != nil {
		t.Fatalf("failed to create email client: %v", err)
	}
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
			got.Logout()
		})
	}
}
