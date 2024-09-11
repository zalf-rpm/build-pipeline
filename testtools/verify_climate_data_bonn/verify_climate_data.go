package main

import (
	"bufio"
	"compress/gzip"
	"encoding/csv"
	"flag"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// verify climate data

// input: climate data in csv.gz format
// time range: 1951-01-01 to 2023-12-31
// folder structure: /beegfs/common/data/climate/dwd/csvs/germany_ubn_1951-01-01_to_2023-12-31
// contains subfolders for each grid row, e.g. 0, 1, 2, ...
// each subfolder contains daily mean climate data column in csv.gz format
// the filename also contains the grid row and column(C181R0 in daily_mean_RES1_C181R0.csv.gz)
//   0/
//     - daily_mean_RES1_C181R0.csv.gz
//     - daily_mean_RES1_C182R0.csv.gz
//   1/
// each file has the following columns, in this order:
//Date
//Precipitation
//TempMin
//TempMean
//TempMax
//Radiation
//SunshineDuration
//SoilMoisture
//SoilTemperature
//Windspeed
//RefETcalc
//RefETdwd
//RelHumCalc
//Gridcell

// check for following errors:
// duplicated header
// missing dates
// dates out of range

// output: print error messages to stdout

func main() {
	// command line arguments
	// folder path
	inputFolder := flag.String("inputFolder", "", "path to the folder containing the climate data")
	// start date
	startDate := flag.String("startDate", "1951-01-01", "start date of the climate data")
	// end date
	endDate := flag.String("endDate", "2023-12-31", "end date of the climate data")
	flag.Parse()

	// check if input folder is provided
	if *inputFolder == "" {
		panic("input folder is required")
	}
	// convert start date and end date to time
	startDateT, err := time.Parse("2006-01-02", *startDate)
	if err != nil {
		panic(err)
	}
	endDateT, err := time.Parse("2006-01-02", *endDate)
	if err != nil {
		panic(err)
	}

	// walk through the folder
	err = filepath.Walk(*inputFolder, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		checkFile(path, info, startDateT, endDateT)
		return nil
	})
	if err != nil {
		panic(err)
	}
}

func checkFile(path string, fileI os.FileInfo, startDate time.Time, endDate time.Time) {

	// skip if file is a directory
	if fileI.IsDir() {
		return
	}
	// check if file is csv.gz, if not skip it
	if !strings.HasSuffix(fileI.Name(), ".csv.gz") {
		return
	}
	println("checking file: " + fileI.Name())

	// check if file name contains grid row and column
	if !strings.Contains(fileI.Name(), "C") || !strings.Contains(fileI.Name(), "R") {
		print("file name does not contain column and row")
	}

	// open gz file
	file, err := os.Open(path)
	if err != nil {
		panic(err)
	}
	defer file.Close()
	// gzip reader
	gz, err := gzip.NewReader(file)
	if err != nil {
		panic(err)
	}
	defer gz.Close()

	csvReader := csv.NewReader(bufio.NewReader(gz))
	csvReader.Comma = '\t'
	// read header
	record, err := csvReader.Read()
	if err != nil {
		panic(err)
	}
	// check if header contains the correct columns
	header := []string{"Date", "Precipitation", "TempMin", "TempMean", "TempMax", "Radiation", "SunshineDuration", "SoilMoisture", "SoilTemperature", "Windspeed", "RefETcalc", "RefETdwd", "RelHumCalc", "Gridcell"}
	if !compareSlices(header, record) {
		print("header does not contain the correct columns")
	}
	wrongDateFormatCount := 0
	wrongDateOrderCount := 0
	nextDate := startDate
	for record, err := csvReader.Read(); err == nil; record, err = csvReader.Read() {
		// check if the line is a duolicate of the header
		if compareSlices(header, record) {
			print("line is a duplicate of the header")
			continue
		}

		// check if date is in the correct range and order
		date := record[0]
		// check if date is in the correct format (YYYY-MM-DD)
		dateTime, err := time.Parse("2006-01-02", date)
		if err != nil {
			print("date is not in the correct format: " + date)
			wrongDateFormatCount++
			if wrongDateFormatCount > 3 {
				print("too many dates in the wrong format")
				break
			}
			continue
		}
		if dateTime.Before(startDate) || dateTime.After(endDate) {
			print("date is not in the correct range: " + date)
			continue
		}
		if dateTime.Compare(nextDate) != 0 {
			print("date is not in the correct order: " + date)
			wrongDateOrderCount++
			if wrongDateOrderCount > 10 {
				print("too many dates in the wrong order")
				break
			}
			continue
		}
		nextDate = nextDate.AddDate(0, 0, 1) // add one day
	}
}

func compareSlices(a []string, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
