package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"
	"strings"
)

const filesPerTurn = 10000

type simFlags []string

func (i *simFlags) String() string {
	return strings.Join(*i, ",")
}

func (i *simFlags) Set(value string) error {
	*i = append(*i, value)
	return nil
}

var mySimFlags simFlags

func main() {

	sourcepathPtr := flag.String("source", "/source/apsimfiles", "current path to outfiles")
	targetPathPtr := flag.String("out", "/out", "new path to outfiles")
	flag.Var(&mySimFlags, "sim", "sim id")
	flag.Parse()

	sourcePath := *sourcepathPtr
	targetPath := *targetPathPtr
	simNames := mySimFlags

	numberOfSims := len(simNames)
	toDelete := make([]string, 0, numberOfSims)
	toMove := make([]string, 0, numberOfSims*9)
	d, err := os.Open(sourcePath)
	if err != nil {
		log.Fatal(err)
	}
	defer d.Close()

	//fmt.Println("sourcePath: ", sourcePath)
	//fmt.Println("targetPath: ", targetPath)
	//fmt.Println("simNames: ", simNames)
	for names, err := d.Readdir(filesPerTurn); err == nil; names, err = d.Readdir(filesPerTurn) {
		for _, name := range names {
			basename := filepath.Base(name.Name())
			if strings.HasSuffix(basename, ".out") {
				for _, simName := range simNames {
					if strings.HasPrefix(basename, simName) {
						toMove = append(toMove, basename)
						break
					}
				}
				continue
			}
			// delete *.sum files
			if strings.HasSuffix(basename, ".sum") {
				for _, simName := range simNames {
					if strings.HasPrefix(basename, simName) {
						toDelete = append(toDelete, basename)
						break
					}
				}
			}
		}
	}
	for _, basename := range toMove {
		// move out files to output folder
		err := os.Rename(filepath.Join(sourcePath, basename), filepath.Join(targetPath, basename))
		if err != nil {
			log.Fatal(err)
		}
		//fmt.Println("Move: ", basename)
	}
	for _, basename := range toDelete {
		err := os.Remove(filepath.Join(sourcePath, basename))
		if err != nil {
			log.Fatal(err)
		}
		//fmt.Println("Remove: ", basename)
	}
}
