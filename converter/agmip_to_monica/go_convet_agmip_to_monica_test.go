package main

import "testing"

func TestConvertAgMIPToMonica(t *testing.T) {
	type args struct {
		folderIn  string
		folderOut string
	}
	tests := []struct {
		name    string
		args    args
		wantErr bool
	}{
		{"general", args{"test_example", "test_example_out"}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := ConvertAgMIPToMonica(tt.args.folderIn, tt.args.folderOut); (err != nil) != tt.wantErr {
				t.Errorf("ConvertAgMIPToMonica() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
