package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// perform tests:
// 		continuesDatesTest
// 		windSpeedTest
// 		precipationTest
// 		globalRadiationTest
// 		temperatureTest
// 		relativeHumidityTest
// 		consistentUnitTests

const (
	continuesDatesTest int = iota
	windSpeedTest
	precipationTest
	globalRadiationTest
	temperatureTest
	relativeHumidityTest
	consistentUnitTests
	generalTest
	numberOfTests
)

var testNames = [...]string{
	"continuesDates",
	"windSpeed",
	"precipation",
	"globalRadiation",
	"temperature",
	"relativeHumidity",
	"consistentUnits",
	"generalTest",
}

// metaData to write a meta file
type metaData struct {
	name                string
	tmin                float64
	tmax                float64
	globalRadMin        float64
	globalRadMax        float64
	relhumidMax         float64
	relhumidMin         float64
	precipationMax      float64
	windMin             float64
	windMax             float64
	startDate           time.Time
	endDate             time.Time
	missingDataSets     bool
	numberOfFailedTests int64
	unitTypeTemp        string
	unitTypeWind        string
	unitTypeglobalRad   string
	unitTypePrecip      string
	unitTypeRelHumid    string

	hasUnits bool
	mux      sync.Mutex
}

func main() {

	// command line flags
	pathPtr := flag.String("path", "/climate/transformed/0/0_0", "path to climate file folder")
	pathMetaPtr := flag.String("meta", "meta", "path to meta file")
	pathErrlogPtr := flag.String("log", "./log", "path to error log folder")
	headerLinesPtr := flag.Int("numHeader", 2, "number of header lines")
	seperatorPtr := flag.String("seperator", ",", "colum seperator")
	concurrentPtr := flag.Int("concurrent", 40, "number of concurrent analytics")

	flag.Parse()

	inputPath := *pathPtr
	outfile := *pathErrlogPtr + "/%s_errOut.log"
	formatSeperator := *seperatorPtr
	formatHeaderLines := *headerLinesPtr
	pathMeta := *pathMetaPtr
	concur := *concurrentPtr

	// create error output / success
	fileOk := make(chan bool)             // ok=1 err=0
	errOut := make(map[int](chan string)) // send error messages
	confirmSaved := make(chan bool)       // finished writing errors

	for i := 0; i < numberOfTests; i++ {
		errOut[i] = make(chan string)
		// concurrent error out (<error channel>, <output file>, <confirm file saved channel> )
		go logOutput(errOut[i], fmt.Sprintf(outfile, testNames[i]), confirmSaved)
	}

	var metaOut chan string = nil
	//var summary metaData
	if pathMeta != "meta" {
		metaOut = make(chan string) // write meta data
		go logOutput(metaOut, pathMeta, confirmSaved)
	}

	// count number of files check concurrently
	numFilesToCheck := 0
	var filesToCheck []os.FileInfo
	var pathsToCheck []string
	// file walker
	err := filepath.Walk(inputPath, func(path string, info os.FileInfo, err error) error {

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
	if metaOut != nil {
		numberOfLogs++
	}
	if numFilesToCheck > 0 {
		filesChecked := 0
		currentFileIndex := 0
		for i := 0; i < concur && currentFileIndex < numFilesToCheck; i++ {
			go checkFile(pathsToCheck[currentFileIndex], formatSeperator, formatHeaderLines, filesToCheck[currentFileIndex], fileOk, errOut, metaOut)
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
					go checkFile(pathsToCheck[currentFileIndex], formatSeperator, formatHeaderLines, filesToCheck[currentFileIndex], fileOk, errOut, metaOut)
					currentFileIndex++
				}
				if numFilesToCheck == filesChecked {
					if metaOut != nil {
						metaOut <- fmt.Sprintf("Files with errors : %d\n", filesWithError)
						metaOut <- fmt.Sprintf("Files okay: %d\n", filesNoError)
						close(metaOut)
					}
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

func checkFile(path, formatSeperator string, formatHeaderLines int, info os.FileInfo, fileOk chan bool, errOut map[int](chan string), metaout chan string) {
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
	var prevClimateLine climateDates
	noErrFound := true
	for scanner.Scan() {
		lineCount++
		if lineCount == 1 {
			headerColumns, err = readHeader(scanner.Text(), formatSeperator)
			if err != nil {
				noErrFound = writeErrorMessage(generalTest, err)
				fileOk <- noErrFound
				return
			}
		}
		if lineCount > formatHeaderLines {
			line := scanner.Text()
			currClimateLine, err := newClimateDates(formatSeperator, line, headerColumns)
			if err != nil {
				noErrFound = writeErrorMessage(generalTest, err)
				fileOk <- noErrFound
				return
			}
			//	   	missing dates
			if lineCount-1 > formatHeaderLines {
				noErrFound = writeErrorMessage(continuesDatesTest, continuesDates(&currClimateLine, &prevClimateLine)) && noErrFound
			}
			noErrFound = writeErrorMessage(windSpeedTest, windSpeed(&currClimateLine)) && noErrFound
			noErrFound = writeErrorMessage(precipationTest, precipation(&currClimateLine)) && noErrFound
			noErrFound = writeErrorMessage(globalRadiationTest, globalRadiation(&currClimateLine)) && noErrFound
			noErrFound = writeErrorMessage(temperatureTest, temperature(&currClimateLine)) && noErrFound
			noErrFound = writeErrorMessage(relativeHumidityTest, relativeHumidity(&currClimateLine)) && noErrFound
			prevClimateLine = currClimateLine
		}

	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
	fileOk <- noErrFound
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
			file.WriteString(currentMessage + "\n")
		}
	}
}

type climateDates struct {
	isodate  string
	wind     float64
	precip   float64
	globrad  float64
	tmax     float64
	tmin     float64
	tavg     float64
	relhumid float64
	time     time.Time
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
)

var headerNames = [...]string{
	"iso-date",
	"tmin",
	"tavg",
	"tmax",
	"precip",
	"globrad",
	"wind",
	"relhumid"}

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
			return nil, fmt.Errorf("Column %s not found", header)
		}
	}

	return headers, nil
}

func newClimateDates(seperator, line string, h map[Header]int) (climateDates, error) {
	tokens := strings.Split(line, seperator)

	var dates climateDates
	var err [8]error
	dates.isodate = tokens[h[isodate]]
	dates.wind, err[0] = strconv.ParseFloat(tokens[h[wind]], 10)
	dates.precip, err[1] = strconv.ParseFloat(tokens[h[precip]], 10)
	dates.globrad, err[2] = strconv.ParseFloat(tokens[h[globrad]], 10)
	dates.tmax, err[3] = strconv.ParseFloat(tokens[h[tmax]], 10)
	dates.tmin, err[4] = strconv.ParseFloat(tokens[h[tmin]], 10)
	dates.tavg, err[5] = strconv.ParseFloat(tokens[h[tavg]], 10)
	dates.relhumid, err[6] = strconv.ParseFloat(tokens[h[relhumid]], 10)
	dates.time, err[7] = time.Parse("2006-01-02", dates.isodate)
	anyError := func(list [8]error) error {
		for _, b := range list {
			if b != nil {
				return b
			}
		}
		return nil
	}(err)

	return dates, anyError
}

func continuesDates(currentData *climateDates, previousData *climateDates) error {

	nextDay := previousData.time.Add(time.Hour * 24)
	if currentData.time != nextDay {
		return fmt.Errorf("Missing dates between  %s and %s", previousData.isodate, currentData.isodate)
	}
	return nil
}

func windSpeed(date *climateDates) error {
	if date.wind < 0 {
		return fmt.Errorf("Wind(%f) < 0, at date %s", date.wind, date.isodate)
	}
	return nil
}

func precipation(date *climateDates) error {
	if date.precip >= 0 && date.precip < 999 {
		return nil
	}
	return fmt.Errorf("Precipation out of bounds value: %f at date %s", date.precip, date.isodate)
}

func globalRadiation(data *climateDates) error {
	currMonth := data.time.Month()
	if data.globrad == 0 && (currMonth > time.February && currMonth < time.October) {
		return fmt.Errorf("Global Radiation < 1 MJ m-2 d-1, value %f at date %s", data.globrad, data.isodate)
	} else if globrad > 38 {
		return fmt.Errorf("Global Radiation > 38 MJ m-2 d-1, value %f at date %s", data.globrad, data.isodate)
	}
	return nil
}

func temperature(data *climateDates) error {
	if data.tavg > data.tmax && data.tmin > data.tavg {
		return fmt.Errorf("Tmin(%f) > Tavg(%f) > Tmax(%f) at date %s", data.tmin, data.tavg, data.tmax, data.isodate)
	} else if data.tavg > data.tmax {
		return fmt.Errorf("Tavg(%f) > Tmax(%f) at date %s", data.tavg, data.tmax, data.isodate)
	} else if data.tmin > data.tavg {
		return fmt.Errorf("Tmin(%f) > Tavg(%f) at date %s", data.tmin, data.tavg, data.isodate)
	}
	return nil
}

func relativeHumidity(data *climateDates) error {
	if data.relhumid >= 1 && data.relhumid <= 100 {
		return nil
	}
	return fmt.Errorf("Relative humidity out of bounds value: %f at date %s", data.relhumid, data.isodate)
}

func consistentUnits(line, seperator string, header map[Header]int, meta *metaData) error {
	tokens := strings.Split(line, seperator)
	uWind := tokens[header[wind]]
	uPrecip := tokens[header[precip]]
	uGloRad := tokens[header[globrad]]
	uTmax := tokens[header[tmax]]
	uTmin := tokens[header[tmin]]
	uTavg := tokens[header[tavg]]
	uRelHumid := tokens[header[relhumid]]
	if uTmax != uTmin || uTmin != uTavg {
		return fmt.Errorf("Inconsisted temperature units")
	}
	err := meta.SetAndVerifyUnits(uPrecip, uRelHumid, uTmax, uWind, uGloRad)
	return err
}

func (m *metaData) SetAndVerifyUnits(precipU, relHumidU, tempU, windU, globalRadU string) error {
	var err error = nil
	m.mux.Lock()
	if !m.hasUnits {
		m.hasUnits = true
		m.unitTypePrecip = precipU
		m.unitTypeRelHumid = relHumidU
		m.unitTypeTemp = tempU
		m.unitTypeWind = windU
		m.unitTypeglobalRad = globalRadU
	} else {
		if m.unitTypeWind != windU ||
			m.unitTypePrecip != precipU ||
			m.unitTypeglobalRad != globalRadU ||
			m.unitTypeTemp != tempU ||
			m.unitTypeRelHumid != relHumidU {
			err = fmt.Errorf("Inconsisted units")
		}
	}
	m.mux.Unlock()
	return err
}

func (m *metaData) SetStartDate(startDate time.Time) error {
	m.mux.Lock()
	if m.startDate.IsZero() {
		m.startDate = startDate
	} else if m.startDate != startDate {
		return fmt.Errorf("Variation in start date %v", startDate)
	}
	m.mux.Unlock()
	return nil
}

func (m *metaData) SetEndDate(endDate time.Time) error {
	m.mux.Lock()
	if m.endDate.IsZero() {
		m.endDate = endDate
	} else if m.endDate != endDate {
		return fmt.Errorf("Variation in end date %v", endDate)
	}
	m.mux.Unlock()
	return nil
}
