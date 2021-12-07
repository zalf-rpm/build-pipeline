package main

import (
	"bufio"
	"fmt"
	"log"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// id year day month doy tmin tmax globalrad -999.9 precip wind vaporpress*10 co2
const lineFmt = "%s %4d %d %d %d %s %s %s -999.9 %s %s %s %d\r\n"

// ConvertMonicaToStics convert weather files from monica format to apsim met format
func ConvertMonicaToStics(folderIn, folderOut, seperator string, co2 int) error {

	inputpath, err := filepath.Abs(folderIn)
	if err != nil {
		return err
	}
	outpath, err := filepath.Abs(folderOut)
	if err != nil {
		return err
	}

	fileCounter := 0
	// walk folder
	err = filepath.Walk(inputpath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Printf("prevent panic by handling failure accessing a path %q: %v\n", path, err)
			return err
		}
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".csv") {

			filenamebase := strings.TrimSuffix(info.Name(), ".csv")
			fulloutpath := filepath.Join(outpath, strings.TrimPrefix(filepath.Dir(path), inputpath), filenamebase)
			fileCounter++

			file, err := os.Open(path)
			if err != nil {
				return err
			}
			defer file.Close()
			scanner := bufio.NewScanner(file)
			// scrip the first 2 lines
			if ok := scanner.Scan(); !ok {
				return scanner.Err()
			}
			headerLine := scanner.Text()
			columns := strings.Split(headerLine, seperator)
			columnMap := make(map[string]int, len(columns))
			for i := 0; i < len(columns); i++ {
				columnMap[columns[i]] = i
			}
			// skip units
			scanner.Scan()
			currentYear := -1
			var outfile *os.File
			var writer *bufio.Writer
			// read all lines
			for scanner.Scan() {
				line := scanner.Text()
				tokens := strings.Split(line, seperator)
				date, err := time.Parse("2006-01-02", tokens[columnMap["iso-date"]])
				if err != nil {
					return err
				}
				tmin, err := strconv.ParseFloat(tokens[columnMap["tmin"]], 64)
				if err != nil {
					return err
				}
				tmax, err := strconv.ParseFloat(tokens[columnMap["tmax"]], 64)
				if err != nil {
					return err
				}
				precip, err := strconv.ParseFloat(tokens[columnMap["precip"]], 64)
				if err != nil {
					return err
				}
				globrad, err := strconv.ParseFloat(tokens[columnMap["globrad"]], 64)
				if err != nil {
					return err
				}
				vaporpress, err := strconv.ParseFloat(tokens[columnMap["vaporpress"]], 64)
				if err != nil {
					return err
				}
				vaporpress = vaporpress * 10
				wind, err := strconv.ParseFloat(tokens[columnMap["wind"]], 64)
				if err != nil {
					return err
				}

				doy := date.YearDay()
				year := date.Year()
				month := date.Month()
				day := date.Day()

				if currentYear != year {
					if outfile != nil {
						writer.Flush()
						outfile.Close()
					}
					currentYear = year
					yearFilename := fulloutpath + "." + strconv.FormatInt(int64(year), 10)
					makeDir(yearFilename)
					fmt.Println(yearFilename)
					outfile, err = os.OpenFile(yearFilename, os.O_TRUNC|os.O_CREATE|os.O_WRONLY, 0660)
					if err != nil {
						return err
					}
					writer = bufio.NewWriter(outfile)
				}
				//id year day month doy tmin tmax globalrad -999.9 precip wind vaporpress*10 co2
				//strconv.FormatFloat(tmin, 'f', -1, 64)
				writer.WriteString(fmt.Sprintf(lineFmt,
					filenamebase,
					year,
					month,
					day,
					doy,
					strconv.FormatFloat(tmin, 'f', -1, 64),
					strconv.FormatFloat(tmax, 'f', -1, 64),
					strconv.FormatFloat(globrad, 'f', -1, 64),
					strconv.FormatFloat(precip, 'f', -1, 64),
					strconv.FormatFloat(wind, 'f', -1, 64),
					strconv.FormatFloat(math.Round(vaporpress*10)/10, 'f', -1, 64),
					co2))
			}
			if outfile != nil {
				writer.Flush()
				outfile.Close()
			}
			return nil
		}
		return nil
	})

	return err
}

func makeDir(outPath string) {
	dir := filepath.Dir(outPath)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if err := os.MkdirAll(dir, os.ModePerm); err != nil {
			log.Fatalf("ERROR: Failed to generate output path %s :%v", dir, err)
		}
	}
}
