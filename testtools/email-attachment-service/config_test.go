package main

import (
	"reflect"
	"testing"
)

func TestLoadConfig(t *testing.T) {

	// write a dummy config file for testing
	err := WriteDummyConfig("test_config.yaml")
	if err != nil {
		t.Fatalf("failed to write dummy config: %v", err)
	}

	type args struct {
		filePath string
	}
	tests := []struct {
		name    string
		args    args
		want    *Config
		wantErr bool
	}{
		{
			name: "valid config",
			args: args{
				filePath: "test_config.yaml",
			},
			want: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "/tmp",
				Password:      "password",
				Username:      "username",
				CredentialKey: "dummyKey",
				Subject:       "subject",
				From:          "from",
				UseOAuth:      true,
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := LoadConfig(tt.args.filePath)
			if (err != nil) != tt.wantErr {
				t.Errorf("LoadConfig() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("LoadConfig() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		c       *Config
		wantErr bool
	}{
		{
			name: "valid config",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "/tmp",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: false,
		},
		{
			name: "invalid config - missing email server",
			c: &Config{
				EmailServer:   "",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "/tmp",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing port",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "",
				MailBox:       "INBOX",
				DownloadPath:  "/tmp",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing shared folder",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "",
				DownloadPath:  "/tmp",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing download path",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing username",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "",
				Username:      "",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing password and credential key",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "",
				Username:      "",
				Password:      "",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "subject",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing subject",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "/tmp",
				Username:      "username",
				Password:      "password",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "",
				From:          "from",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - missing from",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "",
				Username:      "name",
				Password:      "blub",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "bla",
				From:          "",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: 24,
			},
			wantErr: true,
		},
		{
			name: "invalid config - wrong checkup interval",
			c: &Config{
				EmailServer:   "imap.example.com",
				Port:          "993",
				MailBox:       "INBOX",
				DownloadPath:  "",
				Username:      "name",
				Password:      "blub",
				UseOAuth:      false,
				CredentialKey: "",
				Subject:       "bla",
				From:          "",
				OAuth: struct {
					ClientID     string `yaml:"clientId"`
					ClientSecret string `yaml:"clientSecret"`
					TenantID     string `yaml:"tenantId"`
					TokenCache   string `yaml:"tokenCache"`
				}{
					ClientID:     "clientId",
					ClientSecret: "clientSecret",
					TenantID:     "tenantId",
					TokenCache:   "tokenCache",
				},
				Verbose:         true,
				CheckupInterval: -1,
			},
			wantErr: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := tt.c.Validate(); (err != nil) != tt.wantErr {
				t.Errorf("Config.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
