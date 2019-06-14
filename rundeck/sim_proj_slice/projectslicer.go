package main

import (
	"bufio"
	"bytes"
	"io"
	"log"
	"os"
	"strconv"
	"strings"
)

func main() {

	var numProc = 20
	var projectBounarys []int
	argsWithoutProg := os.Args[1:]
	var projectFile string
	var seperator = ","
	for i, arg := range argsWithoutProg {
		if arg == "-help" {
			printHelp()
			return
		}
		if arg == "-proj" && i+1 < len(argsWithoutProg) {
			projectFile = argsWithoutProg[i+1]
		}
		if arg == "-seperator" && i+1 < len(argsWithoutProg) {
			seperator = argsWithoutProg[i+1]
		}
		if arg == "-num" && i+1 < len(argsWithoutProg) {
			num, err := strconv.ParseUint(argsWithoutProg[i+1], 10, 64)
			if err != nil {
				log.Fatal("ERROR: Failed to parse number of concurrent runs")
				return
			}
			numProc = int(num)
		}
	}
	if len(projectFile) == 0 {
		if err != nil {
			log.Fatal("ERROR: missing project file")
			return
		}
	}
	file, err := os.Open(projectFile)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	// lines, err := lineCounter(file)
	// if err != nil {
	// 	log.Fatal(err)
	// }

	// read project bounaries
	var linenumber = 0
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if linenumber == 0 {
			header := strings.Split(line, seperator)
			header
		}
		configLines = append(configLines, line)
		linenumber++
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

}

func lineCounter(r io.Reader) (int, error) {
	buf := make([]byte, 32*1024)
	count := 0
	lineSep := []byte{'\n'}

	for {
		c, err := r.Read(buf)
		count += bytes.Count(buf[:c], lineSep)

		switch {
		case err == io.EOF:
			return count, nil

		case err != nil:
			return count, err
		}
	}
}

func printHelp() {

}
