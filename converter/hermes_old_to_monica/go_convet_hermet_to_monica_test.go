package main

import "testing"

func TestConvertHermesMetToMonica(t *testing.T) {
	type args struct {
		folderIn  string
		folderOut string
	}
	tests := []struct {
		name    string
		args    args
		wantErr bool
	}{
		// TODO add test data
		{"test_true_data", args{"../global_baseline", "../global_baseline_transformed"}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := ConvertHermesMetToMonica(tt.args.folderIn, tt.args.folderOut); (err != nil) != tt.wantErr {
				t.Errorf("ConvertHermesMetToMonica() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
