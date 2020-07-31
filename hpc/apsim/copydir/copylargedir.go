package main

import (
	"flag"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// create jobfiles from a folder of apsim files

const filesPerTurn = 10000

func main() {

	pathPtr := flag.String("src", "/source/apsimfiles", "path to simfiles")
	tempPtr := flag.String("dst", "/destination/apsimfiles", "new path to jobfiles")
	flag.Parse()
	sourcePath := *pathPtr
	tempPath := *tempPtr
	if !strings.HasSuffix(tempPath, "/") {
		tempPath += "/"
	}

	fi, err := os.Stat(sourcePath)
	if err != nil {
		log.Fatal(err)
		return
	}
	if !fi.Mode().IsDir() {
		log.Fatal("is not a directory")
	}

	d, err := os.Open(sourcePath)
	if err != nil {
		log.Fatal(err)
	}
	defer d.Close()

	for names, err := d.Readdir(filesPerTurn); err == nil; names, err = d.Readdir(filesPerTurn) {
		for _, name := range names {
			if name.IsDir() {
				cmd := exec.Command("cp", "-r", filepath.Join(sourcePath, name.Name()), tempPath)
				log.Printf("Running cp -r %s %s ", filepath.Join(sourcePath, name.Name()), tempPath)
				err := cmd.Run()
				if err != nil {
					log.Fatal(err)
				}
			}
		}
	}
}
