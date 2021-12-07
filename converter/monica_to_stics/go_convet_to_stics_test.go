package main

import "testing"

func TestConvertMonicaToStics(t *testing.T) {
	type args struct {
		folderIn  string
		folderOut string
		seperator string
		co2       int
	}
	tests := []struct {
		name    string
		args    args
		wantErr bool
	}{
		// TODO: Add static test cases.
		{"historical", args{"~/go/src/github.com/zalf-rpm/soybean-EU/climate-data/test", "~/go/src/github.com/zalf-rpm/soybean-EU/climate-data/stics/0/0_0", ",", 499}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if err := ConvertMonicaToStics(tt.args.folderIn, tt.args.folderOut, tt.args.seperator, tt.args.co2); (err != nil) != tt.wantErr {
				t.Errorf("ConvertMonicaToMet() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
