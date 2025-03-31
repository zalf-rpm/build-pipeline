package main

import "testing"

func TestGetCredential(t *testing.T) {

	// requirements:
	// windows credential manager
	// target prefix: email-attachment-service
	// target name: email-attachment-service:cluster1
	// credential user: myuser
	// credential password: mypass
	type args struct {
		key string
	}
	tests := []struct {
		name    string
		args    args
		want    string
		want1   string
		wantErr bool
	}{
		{
			name: "valid key",
			args: args{
				key: "cluster1",
			},
			want:    "myuser",
			want1:   "mypass",
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, got1, err := GetCredential(tt.args.key)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetCredential() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if got != tt.want {
				t.Errorf("GetCredential() got = %v, want %v", got, tt.want)
			}
			if got1 != tt.want1 {
				t.Errorf("GetCredential() got1 = %v, want %v", got1, tt.want1)
			}
		})
	}
}
