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
				SharedFolder:  "INBOX",
				DownloadPath:  "/tmp",
				Password:      "password",
				Username:      "username",
				CredentialKey: "dummyKey",
				Subject:       "subject",
				From:          "from",
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
