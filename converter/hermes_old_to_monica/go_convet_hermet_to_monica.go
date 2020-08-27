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

// ConvertHermesMetToMonica convert weather files from hermes format to monica csv format
func ConvertHermesMetToMonica(folderIn, folderOut string) error {

	inputpath, err := filepath.Abs(folderIn)
	if err != nil {
		return err
	}
	outpath, err := filepath.Abs(folderOut)
	if err != nil {
		return err
	}
	// read folder structure
	// copy folder structure for met files
	type climateFiles struct {
		inputPath  string         // path without filename
		outputPath string         // path without filename
		filename   string         // filename to be summed up
		files      map[int]string // filenames, sorted by year
		startYear  int
		endYear    int
	}

	fileList := make(map[string]*climateFiles)
	// walk folder
	err = filepath.Walk(inputpath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			fmt.Printf("prevent panic by handling failure accessing a path %q: %v\n", path, err)
			return err
		}
		// treeDigitYear
		yearExt := func(filename string) (int, bool) {
			ext := filepath.Ext(filename)
			if strings.HasPrefix(ext, ".") {
				i, err := strconv.Atoi(ext[1:])
				if err == nil {
					if i < 900 {
						i = i + 2000
					} else {
						i = i + 1000
					}
					return i, true
				}
			}
			return -1, false
		}
		if !info.IsDir() {
			if year, ok := yearExt(info.Name()); ok {

				filenameID := strings.TrimSuffix(path, filepath.Ext(info.Name()))
				if entry, ok := fileList[filenameID]; ok {
					if year < entry.startYear {
						entry.startYear = year
					} else if year > entry.endYear {
						entry.endYear = year
					}
					entry.files[year] = path
				} else {
					list := make(map[int]string)
					list[year] = path
					outFilename := strings.TrimSuffix(info.Name(), filepath.Ext(info.Name())) + ".csv"
					newEntry := climateFiles{
						inputPath:  filepath.Dir(path),
						outputPath: filepath.Join(outpath, strings.TrimPrefix(filepath.Dir(path), inputpath), outFilename),
						filename:   outFilename,
						files:      list,
						startYear:  year,
						endYear:    year,
					}
					fileList[filenameID] = &newEntry
				}
			}
		}
		return nil
	})

	for _, entry := range fileList {
		makeDir(entry.outputPath)
		fmt.Println(entry.outputPath)
		outFile, err := os.OpenFile(entry.outputPath, os.O_TRUNC|os.O_CREATE|os.O_WRONLY, 0600)
		if err != nil {
			return err
		}

		writer := bufio.NewWriter(outFile)
		writer.WriteString(headlineColumns)
		writer.WriteString(headlineUnits)

		for y := entry.startYear; y <= entry.endYear; y++ {
			file, err := os.Open(entry.files[y])
			if err != nil {
				return err
			}
			defer file.Close()

			scanner := bufio.NewScanner(file)
			// Tp_av;Tpmin;Tpmax;T_s10;T_s20;vappd;wind;sundu;radia;prec;jday RF
			// C_deg;C_deg;C_deg;C_deg;C_deg;mm_Hg;m/sec;hours;J/cm^2;mm ;%
			index := 0
			for scanner.Scan() {

				if index < 3 {
					index++
					continue
				}
				record := strings.FieldsFunc(scanner.Text(), func(r rune) bool {
					if r == ';' {
						return true
					}
					return false
				})

				// date
				jday, err := strconv.ParseInt(strings.TrimSpace(record[10]), 10, 64)
				if err != nil {
					return err
				}
				date := time.Date(y, time.January, int(jday), 0, 0, 0, 0, time.UTC)
				//0		1	  2     3     4     5    6	  7     8     9     10  11
				//Tp_av;Tpmin;Tpmax;T_s10;T_s20;vappd;wind;sundu;radia;prec;jday RF
				tmin, err := strconv.ParseFloat(strings.TrimSpace(record[1]), 64)
				if err != nil {
					return err
				}
				tavg, err := strconv.ParseFloat(strings.TrimSpace(record[0]), 64)
				if err != nil {
					return err
				}
				tmax, err := strconv.ParseFloat(strings.TrimSpace(record[2]), 64)
				if err != nil {
					return err
				}
				precip, err := strconv.ParseFloat(strings.TrimSpace(record[9]), 64)
				if err != nil {
					return err
				}
				relHum, err := strconv.ParseInt(strings.TrimSpace(record[11]), 10, 64)
				if err != nil {
					return err
				}
				rad, err := strconv.ParseFloat(strings.TrimSpace(record[8]), 64)
				if err != nil {
					return err
				}
				globrad := rad / 100
				wind, err := strconv.ParseFloat(strings.TrimSpace(record[6]), 64)
				if err != nil {
					return err
				}
				index++
				str := fmt.Sprintf(lineFmt, date.Format(dateFmt), tmin, tavg, tmax, precip, relHum, globrad, wind)
				writer.WriteString(str)
			}
		}
		writer.Flush()
		outFile.Close()
	}
	return nil
}

func makeDir(outPath string) {
	dir := filepath.Dir(outPath)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if err := os.MkdirAll(dir, os.ModePerm); err != nil {
			log.Fatalf("ERROR: Failed to generate output path %s :%v", dir, err)
		}
	}
}
