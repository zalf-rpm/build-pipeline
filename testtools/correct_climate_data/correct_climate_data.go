package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const (
	globalRadiationTest int = iota
	temperatureTest
	relativeHumidityTest
	generalTest
	numberOfTests
)

var testNames = [...]string{
	"globalRadiation",
	"temperature",
	"relativeHumidity",
	"generalTest",
}

func main() {

	// command line flags
	inpathPtr := flag.String("inpath", "/climate/transformed/0/0_0", "path to climate file folder")
	outpathPtr := flag.String("outpath", "/climate/corrected/0/0_0", "path to climate output file folder")
	pathErrlogPtr := flag.String("log", "./log", "path to error log folder")
	headerLinesPtr := flag.Int("numHeader", 2, "number of header lines")
	seperatorPtr := flag.String("seperator", ",", "colum seperator")
	concurrentPtr := flag.Int("concurrent", 40, "number of concurrent analytics")

	flag.Parse()

	inputPath, err := filepath.Abs(*inpathPtr)
	if err != nil {
		log.Fatal(err)
	}
	outputPath, err := filepath.Abs(*outpathPtr)
	if err != nil {
		log.Fatal(err)
	}
	logfile := *pathErrlogPtr + "/%s_errOut.log"
	formatSeperator := *seperatorPtr
	formatHeaderLines := *headerLinesPtr
	concur := *concurrentPtr

	// create error output / success
	fileOk := make(chan bool)             // ok=1 err=0
	errOut := make(map[int](chan string)) // send error messages
	confirmSaved := make(chan bool)       // finished writing errors

	for i := 0; i < numberOfTests; i++ {
		errOut[i] = make(chan string)
		// concurrent error out (<error channel>, <output file>, <confirm file saved channel> )
		go logOutput(errOut[i], fmt.Sprintf(logfile, testNames[i]), confirmSaved)
	}

	// count number of files check concurrently
	numFilesToCheck := 0
	var filesToCheck []os.FileInfo
	var pathsToCheck []string
	// file walker
	err = filepath.Walk(inputPath, func(path string, info os.FileInfo, err error) error {

		if err != nil {
			fmt.Printf("prevent panic by handling failure accessing a path %q: %v\n", path, err)
			return err
		}
		if matched, _ := filepath.Match("*.csv", info.Name()); !info.IsDir() && matched {
			numFilesToCheck++
			filesToCheck = append(filesToCheck, info)
			pathsToCheck = append(pathsToCheck, path)
		}
		return nil
	})
	if err != nil {
		fmt.Printf("error walking the path %q: %v\n", inputPath, err)
		return
	}

	// wait for all files to be analyzed to close the logs
	logsClosed := 0
	numberOfLogs := numberOfTests
	if numFilesToCheck > 0 {
		filesChecked := 0
		currentFileIndex := 0
		for i := 0; i < concur && currentFileIndex < numFilesToCheck; i++ {
			go checkAndFixFile(pathsToCheck[currentFileIndex], inputPath, outputPath, formatSeperator, formatHeaderLines, filesToCheck[currentFileIndex], fileOk, errOut)
			currentFileIndex++
		}
		var filesWithError int
		var filesNoError int
		for {
			select {
			case isOK, isOpen := <-fileOk:
				if !isOpen {
					return
				}
				if !isOK {
					filesWithError++
				} else {
					filesNoError++
				}
				filesChecked++
				if currentFileIndex < numFilesToCheck {
					go checkAndFixFile(pathsToCheck[currentFileIndex], inputPath, outputPath, formatSeperator, formatHeaderLines, filesToCheck[currentFileIndex], fileOk, errOut)
					currentFileIndex++
				}
				if numFilesToCheck == filesChecked {
					fmt.Printf("Files with errors : %d\n", filesWithError)
					fmt.Printf("Files okay: %d\n", filesNoError)
					for _, testChannel := range errOut {
						close(testChannel)
					}
				}

			case <-confirmSaved:
				logsClosed++
				if logsClosed == numberOfLogs {
					return
				}
			}
		}
	}
}

func checkAndFixFile(path, inputpath, outpath, formatSeperator string, formatHeaderLines int, info os.FileInfo, fileOk chan bool, errOut map[int](chan string)) {

	fulloutpath := filepath.Join(outpath, strings.TrimPrefix(filepath.Dir(path), inputpath))

	// open a climate file
	file, err := os.OpenFile(path, os.O_RDONLY, 0600)
	if err != nil {
		log.Fatalf("Error occured while opening file: %s   \n", path)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)

	// function to write error output with path, return false if error is found
	writeErrorMessage := func(path, name string, errOut map[int](chan string)) func(testID int, err error) bool {
		outC := errOut

		outStr := fmt.Sprintf(">'%s' '%s' :", filepath.Base(filepath.Dir(path)), name)
		return func(testID int, err error) bool {
			if err != nil {
				outC[testID] <- fmt.Sprint(outStr, err.Error())
				return false // error found
			}
			return true
		}
	}(path, info.Name(), errOut)

	lineCount := 0
	var headerColumns map[Header]int
	noErrFound := true
	//radiatonLastDays := newDataLastDays(5)
	relHumidLastDays := newDataLastDays(10)
	var fileContent climateFile
	fileContent.filename = info.Name()
	fileContent.headerAsString = make([]string, formatHeaderLines)
	fileContent.globalRadValues = make(map[int][]float64)
	for scanner.Scan() {
		lineCount++
		line := scanner.Text()
		if lineCount == 1 {
			headerColumns, err = readHeader(line, formatSeperator)
			if err != nil {
				noErrFound = writeErrorMessage(generalTest, err)
				fileOk <- noErrFound
				return
			}
			fileContent.header = headerColumns
		}
		if lineCount <= formatHeaderLines {
			fileContent.headerAsString[lineCount-1] = line
		}
		if lineCount > formatHeaderLines {
			currClimateLine, err := newClimateDates(formatSeperator, line, headerColumns)
			if err != nil {
				noErrFound = writeErrorMessage(generalTest, err)
				fileOk <- noErrFound
				return
			}
			doy := currClimateLine.time.YearDay()
			if _, ok := fileContent.globalRadValues[doy]; !ok {
				fileContent.globalRadValues[doy] = make([]float64, 0, 30)
			}
			var newLine climline
			newLine.text = line
			radError := globalRadiation(&currClimateLine, fileContent.globalRadValues[doy])
			newLine.addError(radError)
			tempError := temperature(&currClimateLine)
			newLine.addError(tempError)
			relHumError := relativeHumidity(&currClimateLine, relHumidLastDays.getData())
			newLine.addError(relHumError)
			fileContent.addLine(newLine)

			noErrFound = writeErrorMessage(globalRadiationTest, radError) && noErrFound
			noErrFound = writeErrorMessage(temperatureTest, tempError) && noErrFound
			noErrFound = writeErrorMessage(relativeHumidityTest, relHumError) && noErrFound
			//radiatonLastDays.addDay(currClimateLine.globrad)
			relHumidLastDays.addDay(currClimateLine.relhumid)

			fileContent.globalRadValues[doy] = append(fileContent.globalRadValues[currClimateLine.time.YearDay()], currClimateLine.globrad)
		}

	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	if !noErrFound {
		fileContent.correctErrors(formatSeperator)
	}
	fileContent.Save(fulloutpath)
	fileOk <- noErrFound
}
func (c *climateFile) correctErrors(seperator string) {
	// correct Errors
	numberOfLines := len(c.lines)
	for _, errIndex := range c.linesWithError {
		for _, errMsg := range c.lines[errIndex].err {
			tokens := strings.Split(c.lines[errIndex].text, seperator)
			if strings.HasPrefix(errMsg.Error(), "TempSwap:") {
				// swap temp
				tmaxStr := tokens[c.header[tmax]]
				tminStr := tokens[c.header[tmin]]
				tokens[c.header[tmax]] = tminStr
				tokens[c.header[tmin]] = tmaxStr
				c.lines[errIndex].text = strings.Join(tokens, seperator)
			} else if strings.HasPrefix(errMsg.Error(), "Rad0:") {
				t, _ := time.Parse("2006-01-02", tokens[c.header[isodate]])
				doy := t.YearDay()
				// set avg Rad
				num := 0
				var sumRad float64
				for _, rad := range c.globalRadValues[doy] {
					num++
					sumRad = sumRad + rad
				}
				if num > 0 {
					avg := sumRad / float64(num)
					tokens[c.header[globrad]] = fmt.Sprintf("%.1f", avg)
					c.lines[errIndex].text = strings.Join(tokens, seperator)
				}
			} else if strings.HasPrefix(errMsg.Error(), "RelhumLow:") {
				// set avg rel humidity
				lowerBound := max(0, errIndex-10)
				upperBound := min(numberOfLines-1, errIndex+10)
				currentRelHum, _ := strconv.ParseFloat(tokens[c.header[relhumid]], 10)
				var relHSum float64
				num := 0
				for i := lowerBound; i <= upperBound; i++ {
					if i == errIndex {
						continue
					}
					lineTokens := strings.Split(c.lines[i].text, seperator)
					relHum, _ := strconv.ParseFloat(lineTokens[c.header[relhumid]], 10)
					if relHum > 1 {
						relHSum = relHSum + relHum
						num++
					}
				}
				if num > 0 {
					avg := relHSum / float64(num)
					if avg > currentRelHum {
						tokens[c.header[relhumid]] = fmt.Sprintf("%.1f", avg)
						c.lines[errIndex].text = strings.Join(tokens, seperator)
					}
				}
			}
			// tbd
		}
	}
}
func (c *climateFile) Save(path string) {
	fullpath := filepath.Join(path, c.filename)
	createDirErr := os.MkdirAll(path, os.ModePerm)
	if createDirErr != nil {
		log.Fatalf("Error occured while opening output file: %s   \n", fullpath)
	}

	file, err := os.OpenFile(fullpath, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if err != nil {
		log.Fatalf("Error occured while opening output file: %s   \n", fullpath)
	}
	defer file.Close()
	for _, h := range c.headerAsString {
		file.WriteString(fmt.Sprintln(h))
	}
	for _, line := range c.lines {
		file.WriteString(fmt.Sprintln(line.text))
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// logOutput recives messages and writes them in a file
func logOutput(input chan string, outfile string, confirmSaved chan bool) {

	var file *os.File
	var err error
	for {
		select {
		case currentMessage, ok := <-input:
			if !ok {
				if file != nil {
					file.Close()
					confirmSaved <- true
				}
				confirmSaved <- false
				return
			}
			if file == nil {
				file, err = os.OpenFile(outfile, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
				if err != nil {
					log.Fatalf("Error occured while opening output file: %s   \n", outfile)
				}
			}
			file.WriteString(fmt.Sprintln(currentMessage))
		}
	}
}

type climateDates struct {
	isodate    string
	wind       float64
	precip     float64
	globrad    float64
	tmax       float64
	tmin       float64
	tavg       float64
	relhumid   float64
	vaporpress float64
	time       time.Time
}

// iso-date,tmin,tavg,tmax,precip,globrad,wind,relhumid,vaporpress,dewpoint_temp,relhumid_tmin,relhumid_tmax

//Header of weather csv file
type Header int

const (
	isodate Header = iota
	tmin
	tavg
	tmax
	precip
	globrad
	wind
	relhumid
	vaporpress
)

var headerNames = [...]string{
	"iso-date",
	"tmin",
	"tavg",
	"tmax",
	"precip",
	"globrad",
	"wind",
	"relhumid",
	"vaporpress",
}

var optionalHeader = map[Header]bool{
	relhumid:   true,
	vaporpress: true,
}

func readHeader(line, seperator string) (map[Header]int, error) {
	tokens := strings.Split(line, seperator)
	headers := make(map[Header]int)
	for h, header := range headerNames {
		found := false
		for i, token := range tokens {
			if token == header {
				headers[Header(h)] = i
				found = true
				break
			}
		}
		if !found {
			if _, ok := optionalHeader[Header(h)]; !ok {
				return nil, fmt.Errorf("Column %s not found", header)
			}
		}
	}

	return headers, nil
}

func newClimateDates(seperator, line string, h map[Header]int) (climateDates, error) {
	tokens := strings.Split(line, seperator)

	var dates climateDates
	err := make([]error, 9)
	dates.isodate = tokens[h[isodate]]
	dates.wind, err[0] = strconv.ParseFloat(tokens[h[wind]], 10)
	dates.precip, err[1] = strconv.ParseFloat(tokens[h[precip]], 10)
	dates.globrad, err[2] = strconv.ParseFloat(tokens[h[globrad]], 10)
	dates.tmax, err[3] = strconv.ParseFloat(tokens[h[tmax]], 10)
	dates.tmin, err[4] = strconv.ParseFloat(tokens[h[tmin]], 10)
	dates.tavg, err[5] = strconv.ParseFloat(tokens[h[tavg]], 10)
	if _, ok := h[relhumid]; ok {
		dates.relhumid, err[6] = strconv.ParseFloat(tokens[h[relhumid]], 10)
	}
	if _, ok := h[vaporpress]; ok {
		dates.vaporpress, err[7] = strconv.ParseFloat(tokens[h[vaporpress]], 10)
	}
	dates.time, err[8] = time.Parse("2006-01-02", dates.isodate)
	anyError := func(list []error) error {
		for _, b := range list {
			if b != nil {
				return b
			}
		}
		return nil
	}(err)

	return dates, anyError
}

func globalRadiation(data *climateDates, prevDates []float64) error {

	avgerage := avgRad(prevDates)
	if data.globrad == 0 && avgerage > 1.7 {
		return fmt.Errorf("Rad0: Global Radiation < 1 MJ m-2 d-1, value %f at date %s", data.globrad, data.isodate)
	}
	return nil
}
func avgRad(prevDates []float64) float64 {
	if prevDates == nil || len(prevDates) == 0 {
		return 0.5
	}
	var avgSum float64
	var num float64
	for _, date := range prevDates {
		if date > 0 {
			avgSum = date + avgSum
			num++
		}
	}
	var avg float64
	if num > 0 && avgSum > 0 {
		avg = avgSum / num
	}
	return avg
}

func temperature(data *climateDates) error {
	if data.tmin > data.tmax {
		return fmt.Errorf("TempSwap: Tmin(%f) > Tmax(%f) at date %s", data.tmin, data.tmax, data.isodate)
	}

	return nil
}

func relativeHumidity(data *climateDates, prevDates []float64) error {
	average := avgHumid(prevDates)

	if data.relhumid < 10.0 && data.relhumid < math.Max(1, average-10) {
		return fmt.Errorf("RelhumLow: Relative humidity value: %f at date %s", data.relhumid, data.isodate)
	}
	return nil
}
func avgHumid(prevDates []float64) float64 {
	if prevDates == nil || len(prevDates) == 0 {
		return 10.0
	}
	var avgSum float64
	var num float64
	for _, date := range prevDates {
		if date > 0 {
			avgSum = date + avgSum
			num++
		}
	}
	var avg float64
	if num > 0 && avgSum > 0 {
		avg = avgSum / num
	}
	return avg
}

type dataLastDays struct {
	arr        []float64
	index      int
	currentLen int
	capacity   int
}

func newDataLastDays(days int) dataLastDays {
	return dataLastDays{arr: make([]float64, days), index: 0, capacity: days}
}

func (d *dataLastDays) addDay(val float64) {
	if d.index < d.capacity-1 {
		d.index++
		if d.currentLen < d.capacity {
			d.currentLen++
		}
	} else {
		d.index = 0
	}
	d.arr[d.index] = val
}

func (d *dataLastDays) getData() []float64 {
	if d.currentLen == 0 {
		return nil
	}
	return d.arr[:d.currentLen]
}

type climateFile struct {
	filename        string
	headerAsString  []string
	header          map[Header]int
	lines           []climline
	linesWithError  []int
	globalRadValues map[int][]float64
}

func (c *climateFile) addLine(line climline) {
	index := 0
	if c.lines == nil {
		c.lines = make([]climline, 1, 1000)
		c.lines[0] = line
	} else {
		index = len(c.lines)
		c.lines = append(c.lines, line)
	}
	if line.hasError() {
		if c.linesWithError == nil {
			c.linesWithError = []int{index}
		} else {
			c.linesWithError = append(c.linesWithError, index)
		}
	}
}

type climline struct {
	text string
	err  []error
}

func (l *climline) hasError() bool {
	return len(l.err) > 0
}

func (l *climline) addError(err error) {
	if err != nil {
		if l.err == nil {
			l.err = []error{err}
		} else {
			l.err = append(l.err, err)
		}
	}
}
