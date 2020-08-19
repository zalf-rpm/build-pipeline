package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const headlineColumns = "iso-date,tmin,tavg,tmax,precip,relhumid,globrad,windspeed\r\n"
const headlineUnits = "[],[°C],[°C],[°C],[mm],[%],[MJ m-2],[m s-1]\r\n"
const dateFmt = "2006-01-02"
const lineFmt = "%s,%1.1f,%1.1f,%1.1f,%1.1f,%d,%1.1f,%1.1f\r\n"

// ConvertAgMIPToMonica convert weather files from AgMIP format to monica csv format
func ConvertAgMIPToMonica(folderIn, folderOut string) error {

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
		if !info.IsDir() && strings.HasSuffix(info.Name(), ".AgMIP") {

			filename := strings.TrimSuffix(info.Name(), ".AgMIP") + ".met"
			fulloutpath := filepath.Join(outpath, strings.TrimPrefix(filepath.Dir(path), inputpath), filename)
			fileCounter++

			// copy folder structure
			makeDir(fulloutpath)
			fmt.Println(fulloutpath)
			outFile, err := os.OpenFile(fulloutpath, os.O_TRUNC|os.O_CREATE|os.O_WRONLY, 0600)
			if err != nil {
				return err
			}
			writer := bufio.NewWriter(outFile)
			writer.WriteString(headlineColumns)
			writer.WriteString(headlineUnits)

			file, err := os.Open(path)
			if err != nil {
				return err
			}
			defer file.Close()
			scanner := bufio.NewScanner(file)
			// skip first 4 lines
			for i := 0; i < 5; i++ {
				if ok := scanner.Scan(); !ok {
					return scanner.Err()
				}
			}
			headerLine := scanner.Text() // 5th line is the header
			columns := strings.Fields(headerLine)
			columnMap := make(map[string]int, len(columns))
			for i := 0; i < len(columns); i++ {
				columnMap[columns[i]] = i
			}
			// read all lines
			for scanner.Scan() {
				line := scanner.Text()
				tokens := strings.Fields(line)
				//"@DATE    YYYY  MM  DD  SRAD  TMAX  TMIN  RAIN  WIND  DEWP  VPRS  RHUM"
				//--- date ----
				year, err := strconv.ParseInt(tokens[columnMap["YYYY"]], 10, 32)
				if err != nil {
					return err
				}
				month, err := strconv.ParseInt(tokens[columnMap["MM"]], 10, 32)
				if err != nil {
					return err
				}
				day, err := strconv.ParseInt(tokens[columnMap["DD"]], 10, 32)
				if err != nil {
					return err
				}
				date := time.Date(int(year), time.Month(month), int(day), 0, 0, 0, 0, time.UTC)
				tmin, err := strconv.ParseFloat(tokens[columnMap["TMIN"]], 64)
				if err != nil {
					return err
				}
				tmax, err := strconv.ParseFloat(tokens[columnMap["TMAX"]], 64)
				if err != nil {
					return err
				}
				tavg := (tmax + tmin) / 2

				precip, err := strconv.ParseFloat(tokens[columnMap["RAIN"]], 64)
				if err != nil {
					return err
				}
				globrad, err := strconv.ParseFloat(tokens[columnMap["SRAD"]], 64)
				if err != nil {
					return err
				}
				wind, err := strconv.ParseFloat(tokens[columnMap["WIND"]], 64)
				if err != nil {
					return err
				}
				relHum, err := strconv.ParseInt(tokens[columnMap["RHUM"]], 10, 64)
				if err != nil {
					return err
				}
				//iso-date,tmin,tavg,tmax,precip,relhumid,globrad,windspeed
				str := fmt.Sprintf(lineFmt, date.Format(dateFmt), tmin, tavg, tmax, precip, relHum, globrad, wind)
				writer.WriteString(str)
			}
			writer.Flush()
			outFile.Close()
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
