package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

func main() {

	args := os.Args[1:]

	projectFile := args[0]
	maxCPU, err := strconv.ParseInt(args[1], 10, 64)
	if err != nil {
		log.Fatal(err)
	}
	maxNodes, err := strconv.ParseInt(args[2], 10, 64)
	if err != nil {
		log.Fatal(err)
	}

	cpuUsage := 1
	tasks := 1
	nodes := int(maxNodes)
	var sliceStr string
	projectMap, min, max := readProj(projectFile, 1)
	numEntries := len(projectMap)
	enable := true
	if min == max && enable {
		maxSplit := numEntries
		if max >= int(maxCPU) {
			cpuUsage = int(maxCPU)
			tasks = int(maxNodes)
		} else {
			cpuUsage = max
			tasks = (int(maxCPU) / max) * int(maxNodes)
		}
		if maxSplit < tasks {
			tasks = maxSplit
		}
		if tasks <= int(maxNodes) {
			nodes = tasks
		}
		entrySlice := maxSplit / tasks
		modEntrySlice := maxSplit % tasks

		sliceStr = "1-"
		tVal := 0
		i := 0
		for ; i < modEntrySlice; i++ {
			tVal = tVal + (max * (entrySlice + 1))
			sliceStr = fmt.Sprintf("%s%d,%d-", sliceStr, tVal, tVal+1)
		}
		for ; i < tasks; i++ {

			tVal = tVal + (max * entrySlice)

			if i == tasks-1 {
				sliceStr += strconv.Itoa(tVal)
			} else {
				sliceStr = fmt.Sprintf("%s%d,%d-", sliceStr, tVal, tVal+1)
			}
		}
		fmt.Println(sliceStr)
		fmt.Printf("nodes: %d\n", nodes)
		fmt.Printf("cpu: %d\n", cpuUsage)
	} else {
		sumEntries := 0
		for _, val := range projectMap {
			sumEntries += val
		}
		if maxNodes > 0 && sumEntries > 0 {
			sliceStr, nodes := splitIrregularProjectFile(projectFile, 1, int(maxNodes), sumEntries)
			fmt.Println(sliceStr)
			fmt.Printf("nodes: %d\n", nodes)
			fmt.Printf("cpu: %d\n", max)
		}

	}
}
func splitIrregularProjectFile(filename string, ignoreLines int, numSlices int, sumEntries int) (string, int) {

	strSlice := "1-"
	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	numline := 0
	index := 0
	sliceSize := sumEntries / numSlices
	if sliceSize == 0 {
		sliceSize = 1
	}
	currentSliceSize := 0
	currentProjID := ""
	currentSlice := 1
	for scanner.Scan() {
		line := scanner.Text()
		if numline >= ignoreLines {

			fields := strings.FieldsFunc(line, func(r rune) bool { return r == ',' })
			projID := fields[0]
			if currentProjID == "" {
				currentProjID = projID
			}
			currentSliceSize++
			if projID != currentProjID {
				if currentSliceSize > sliceSize && currentSlice != numSlices {
					// start a new slice
					currentSlice++
					currentSliceSize = 0
					strSlice = fmt.Sprintf("%s%d,%d-", strSlice, index, index+1)
				}
				currentProjID = projID
			}
			index++
		}
		numline++
	}
	strSlice += strconv.Itoa(index)
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	return strSlice, currentSlice
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
