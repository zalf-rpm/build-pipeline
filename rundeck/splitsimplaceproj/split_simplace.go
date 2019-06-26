package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"log"
	"os"
	"path"
	"strconv"
)

type projectIDCount struct {
	ID    []byte
	Count int64
}

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

	var cpuUsage int64 = 1
	var tasks int64 = 1
	nodes := maxNodes
	var sliceStr string
	projectMap, min, max, linesSum, err := readProjectFile(projectFile)
	if err != nil {
		log.Fatal(err)
	}
	numEntries := int64(len(projectMap))
	enable := true
	if min == max && enable {
		maxSplit := numEntries
		if max >= maxCPU {
			cpuUsage = maxCPU
			tasks = maxNodes
		} else {
			cpuUsage = max
			tasks = (maxCPU / max) * maxNodes
		}
		if maxSplit < tasks {
			tasks = maxSplit
		}
		if tasks <= maxNodes {
			nodes = tasks
		}
		entrySlice := maxSplit / tasks
		modEntrySlice := maxSplit % tasks

		sliceStr = "1-"
		var tVal int64
		var i int64
		for ; i < modEntrySlice; i++ {
			tVal = tVal + (max * (entrySlice + 1))
			sliceStr = fmt.Sprintf("%s%d,%d-", sliceStr, tVal, tVal+1)
		}
		for ; i < tasks; i++ {

			tVal = tVal + (max * entrySlice)

			if i == tasks-1 {
				sliceStr += strconv.FormatInt(tVal, 10)
			} else {
				sliceStr = fmt.Sprintf("%s%d,%d-", sliceStr, tVal, tVal+1)
			}
		}
		fmt.Println(sliceStr)
		fmt.Printf("nodes: %d\n", nodes)
		fmt.Printf("cpu: %d\n", cpuUsage)
	} else {
		cpuUsage := max
		if max > maxCPU {
			cpuUsage = maxCPU
		}
		var sumEntries int64
		for _, val := range projectMap {
			sumEntries += val.Count
		}
		if maxNodes > 0 && linesSum > 0 {
			sliceStr, nodes := splitProjectFile(projectMap, maxNodes, linesSum)
			fmt.Println(sliceStr)
			fmt.Printf("nodes: %d\n", nodes)
			fmt.Printf("cpu: %d\n", cpuUsage)
		}

	}
}

func readProjectFile(filename string) (resMap []projectIDCount, minVal, maxVal, linesSum int64, err error) {
	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	var tarReader *tar.Reader
	if path.Ext(filename) == "tar.gz" {
		tarReader = readTarGzipFile(file)
	}

	buf := make([]byte, 32*1024)
	var count int64

	readID := false
	var previousID []byte
	var currentID []byte
	for {
		var c int
		var err error
		if tarReader != nil {
			c, err = tarReader.Read(buf)
		} else {
			c, err = file.Read(buf)
		}
		if c > 0 {
			for i := 0; i < c; i++ {
				if '\n' == buf[i] {
					readID = true
					currentID = []byte{}
				} else if ',' == buf[i] && readID {
					readID = false
					if !bytes.Equal(previousID, currentID) && len(previousID) > 0 {
						resMap = append(resMap, projectIDCount{ID: previousID, Count: count})
						if count < minVal || minVal == 0 {
							minVal = count
						}
						if count > maxVal {
							maxVal = count
						}
						count = 1
					} else {
						count++
					}
					linesSum++
					previousID = currentID

				} else if readID {
					currentID = append(currentID, buf[i])
				}
			}
		}
		switch {
		case err == io.EOF:
			// add the last
			resMap = append(resMap, projectIDCount{ID: previousID, Count: count})
			if count < minVal || minVal == 0 {
				minVal = count
			}
			if count > maxVal {
				maxVal = count
			}
			return resMap, minVal, maxVal, linesSum, nil

		case err != nil:
			return resMap, minVal, maxVal, linesSum, err
		}
	}
}

func splitProjectFile(resMap []projectIDCount, numSlices, sumEntries int64) (string, int64) {
	strSlice := "1-"
	sliceSize := sumEntries / numSlices
	if sliceSize == 0 {
		sliceSize = 1
	}
	var index int64
	var currentSliceSize int64
	var currentSlice int64 = 1
	for _, entry := range resMap {

		if currentSliceSize >= sliceSize && currentSlice != numSlices {
			// start a new slice
			currentSlice++
			currentSliceSize = 0
			strSlice = fmt.Sprintf("%s%d,%d-", strSlice, index, index+1)
		}
		currentSliceSize = currentSliceSize + entry.Count
		index = index + entry.Count
	}
	strSlice += strconv.FormatInt(index, 10)
	return strSlice, currentSlice
}

func readTarGzipFile(file *os.File) (reader *tar.Reader) {
	// open gzip reader
	gzf, err := gzip.NewReader(file)
	if err != nil {
		log.Fatal(err)
	}
	// open tar reader
	tarReader := tar.NewReader(gzf)

	// should contain exacly one file
	header, err := tarReader.Next()
	if err == io.EOF {
		log.Fatal("File is empty")
	}
	if err != nil {
		log.Fatal(err)
	}

	switch header.Typeflag {
	case tar.TypeReg:
		return tarReader
	default:
		log.Fatal("unable to read file in tar.gz")
	}
	return nil
}
