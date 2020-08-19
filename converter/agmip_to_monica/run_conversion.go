package main

import (
	"flag"
	"fmt"
)

type args struct {
	folderIn  string
	folderOut string
}

func main() {
	sourcePtr := flag.String("source", "", "path to source folder")
	outPtr := flag.String("output", "", "path to out folder")
	flag.Parse()

	cmdl := args{folderIn: *sourcePtr,
		folderOut: *outPtr,
	}

	if err := ConvertAgMIPToMonica(cmdl.folderIn, cmdl.folderOut); err != nil {
		fmt.Print(err)
	}

}
