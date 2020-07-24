package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

// create jobfiles from a folder of apsim files

const filesPerTurn = 10000

func main() {

	pathPtr := flag.String("path", "/source/apsimfiles", "path to simfiles")
	tempPtr := flag.String("temp", "/temp/apsimfiles", "path to jobfiles")
	numNodesPtr := flag.Int("numnodes", 1, "number of nodes used")
	flag.Parse()
	sourcePath := *pathPtr
	tempPath := *tempPtr
	numNodes := *numNodesPtr
	if numNodes < 1 || numNodes > 100 {
		log.Fatal("number of nodes out of bounds")
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
	jobfiles := make([]*Fout, numNodes)
	var isValid [filesPerTurn]bool
	var counter int
	for names, err := d.Readdir(filesPerTurn); err == nil; names, err = d.Readdir(filesPerTurn) {
		for i, name := range names {
			if !name.IsDir() && strings.HasSuffix(name.Name(), ".apsim") {
				counter++
				isValid[i] = true
			} else {
				isValid[i] = false
			}
		}
		index := 1
		for i, name := range names {
			if isValid[i] {
				jobIndex := index % numNodes
				jobID := jobIndex
				if jobfiles[jobID] == nil {
					file, err := os.OpenFile(filepath.Join(tempPath, fmt.Sprintf("jobfile%d.txt", jobIndex+1)), os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
					if err != nil {
						log.Fatal(err)
						return
					}
					fwriter := bufio.NewWriter(file)
					jobfiles[jobID] = &Fout{file, fwriter}
				}
				jobfiles[jobID].Write(filepath.Base(name.Name()))
				jobfiles[jobID].Write("\n")
				index++
			}
		}
	}
	for _, jobfile := range jobfiles {
		if jobfile != nil {
			jobfile.Close()
		}
	}
}

//Fout bufferd file writer
type Fout struct {
	file    *os.File
	fwriter *bufio.Writer
}

// Write string to bufferd file
func (f *Fout) Write(s string) {
	f.fwriter.WriteString(s)
}

// Close file writer
func (f *Fout) Close() {
	f.fwriter.Flush()
	f.file.Close()
}
