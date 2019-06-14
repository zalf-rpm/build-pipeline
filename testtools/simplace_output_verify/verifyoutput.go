package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
)

func main() {

	args := os.Args[1:]

	outputFile := args[0]
	projectFile := args[1]

	projectMap, _, _ := readProj(projectFile, 1)
	resultMap, minR, maxR := readProj(outputFile, 0)

	found := 0
	counter := 0
	for key := range projectMap {
		if _, exists := resultMap[key]; !exists {
			fmt.Println(key)
			counter++
		} else {
			found++
		}

	}
	fmt.Printf("missing entries :%d to found: %d\n", counter, found)
	if minR != maxR {
		fmt.Printf("output has missing results %d to %d\n", minR, maxR)
	}
	for key, val := range resultMap {
		if val < maxR {
			fmt.Println(key)
		}
	}

}

func readProj(filename string, ignoreLines int) (resMap map[string]int, minVal, maxVal int) {
	resMap = make(map[string]int)
	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	numline := 0
	for scanner.Scan() {
		line := scanner.Text()
		if numline >= ignoreLines {
			fields := strings.FieldsFunc(line, func(r rune) bool { return r == ',' })
			projID := fields[0]
			if _, exists := resMap[projID]; exists {
				resMap[projID]++
			} else {
				resMap[projID] = 1
			}
		}
		numline++
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	for _, val := range resMap {
		if minVal == 0 || minVal > val {
			minVal = val
		}
		if maxVal < val {
			maxVal = val
		}
	}

	return resMap, minVal, maxVal
}
