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
)

// header
var title = "%s"
var model = "Model: %s"
var modelerName = "Modeler_name: %s"
var simulation = "Simulation: %s"
var site = "Site: %s"

const header1 = "Model	Planting.date	Treatment	Yield	Emergence	Ant	Mat	FLN	GNumber	Biom-an	Biom-ma	MaxLAI	WDrain	CumET	SoilAvW	Runoff	Transp	CroN-an	CroN-ma	Nleac	GrainN	Nmin	Nvol	Nimmo	SoilN	Nden	cumPARi"
const header2 = "(2letters)	(YYYY-MM-DD)	(-)	(t/ha)	(YYYY-MM-DD)	(YYYY-MM-DD)	(YYYY-MM-DD)	(leaf/mainstem)	(grain/m2)	(t/ha)	(t/ha)	(-)	(mm)	(mm)	(mm)	(mm)	(mm)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(kgN/ha)	(MJ/m^2)"

const newLine = "\r\n"       // line ending
const sepeartor = '\t'       // in- and output seperator
const na = "na"              // not available string
const auswaschungsTiefe = 20 // layer

func main() {
	// flags
	sourcePtr := flag.String("source", "./", "path to source folder")
	outPtr := flag.String("output", "./", "path to out folder")
	titlePtr := flag.String("title", "AgMIP_Wheat_34_Gobal_Sites", "title")
	modelPtr := flag.String("model", "MONICA", "model name")
	simulationPtr := flag.String("simulation", "Step1", "simulation name")
	sitePtr := flag.String("site", "", "site name")
	filenamePtr := flag.String("filename", "AgMIP_Wheat_Summary_Phase4_%s.csv", "file name template")
	modellerPtr := flag.String("modeller", "Claas Nendel", "modeller name")
	treatmentPtr := flag.String("treatment", "na", "treatment id")

	flag.Parse()

	cmdl := cmdlargs{folderIn: *sourcePtr,
		folderOut:  *outPtr,
		title:      *titlePtr,
		model:      *modelPtr,
		simulation: *simulationPtr,
		site:       *sitePtr,
		filename:   *filenamePtr,
		modeller:   *modellerPtr,
		treatment:  *treatmentPtr,
	}

	if err := ConvertOutput(cmdl); err != nil {
		fmt.Print(err)
	}
}

// ConvertOutput convert monica daily out to agmip
func ConvertOutput(args cmdlargs) error {

	inputpath, err := filepath.Abs(args.folderIn)
	if err != nil {
		return err
	}
	outpath, err := filepath.Abs(args.folderOut)
	if err != nil {
		return err
	}

	iDir, err := os.Open(inputpath)
	if err != nil {
		log.Fatal(err)
	}
	defer iDir.Close()

	type outArr struct {
		name      string
		yearMap   map[int]string
		startYear int
		endYear   int
	}
	filenameMap := make(map[string]*outArr)

	fileNames, err := iDir.Readdir(-1)
	for _, filename := range fileNames {
		if !filename.IsDir() && strings.HasSuffix(filename.Name(), ".csv") {
			getYearfromFilename := func(f string) (int, string, error) {
				noSuff := strings.TrimSuffix(f, ".csv")
				yearStr := noSuff[len(noSuff)-4:]
				name := noSuff[:len(noSuff)-4]
				year64, err := strconv.ParseInt(yearStr, 10, 32)
				if err != nil {
					return -1, "", err
				}
				return int(year64), name, err
			}
			year, name, err := getYearfromFilename(filename.Name())
			if err != nil {
				return err
			}
			//fmt.Println(year, name)
			if _, ok := filenameMap[name]; !ok {
				entry := outArr{
					name:      name,
					yearMap:   make(map[int]string),
					startYear: year,
					endYear:   year,
				}
				filenameMap[name] = &entry
			}
			filenameMap[name].yearMap[year] = filepath.Join(inputpath, filename.Name())
			if filenameMap[name].startYear > year {
				filenameMap[name].startYear = year
			}
			if filenameMap[name].endYear < year {
				filenameMap[name].endYear = year
			}
		}
	}
	lastFolder := filepath.Base(inputpath)
	var twoRunes string
	idxRunes := 0
	for _, r := range lastFolder {
		if idxRunes >= 2 {
			break
		}
		twoRunes = twoRunes + string(r)
		idxRunes++
	}

	for _, fileEntyVal := range filenameMap {

		fmtFilename := args.filename
		if strings.Contains(args.filename, "%s") {
			fmtFilename = fmt.Sprintf(args.filename, twoRunes)
		}

		outputfile := filepath.Join(outpath, fmtFilename)
		makeDir(outputfile)
		fmt.Println(outputfile)
		outFile, err := os.OpenFile(outputfile, os.O_TRUNC|os.O_CREATE|os.O_WRONLY, 0600)
		if err != nil {
			return err
		}

		writer := bufio.NewWriter(outFile)
		writer.WriteString(fmt.Sprintf(title, args.title))
		writer.WriteString(newLine)
		writer.WriteString(fmt.Sprintf(model, args.model))
		writer.WriteString(newLine)
		writer.WriteString(fmt.Sprintf(modelerName, args.modeller))
		writer.WriteString(newLine)
		writer.WriteString(fmt.Sprintf(simulation, args.simulation))
		writer.WriteString(newLine)
		writer.WriteString(fmt.Sprintf(site, args.site))
		writer.WriteString(newLine)
		writer.WriteString(header1)
		writer.WriteString(newLine)
		writer.WriteString(header2)
		writer.WriteString(newLine)

		for year := fileEntyVal.startYear; year <= fileEntyVal.endYear; year++ {
			header, content, err := readDailyOutputFile(fileEntyVal.yearMap[year])
			if err != nil {
				return err
			}
			harvestIndex, err := getHarvestIndex(&header, &content)
			if err != nil {
				return err
			}
			// Model
			writer.WriteString("MO")
			writer.WriteRune(sepeartor)
			// Planting.date
			sowIndex, date, err := getStageStartDate("1", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Treatment
			writer.WriteString(args.treatment)
			writer.WriteRune(sepeartor)
			// Yield
			date, err = getYield(harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Emergence
			_, date, err = getStageStartDate("2", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Ant
			antIndex, date, err := getStageStartDate("5", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Mat
			_, date, err = getStageStartDate("6", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// FLN
			writer.WriteString("na")
			writer.WriteRune(sepeartor)
			// GNumber
			writer.WriteString("na")
			writer.WriteRune(sepeartor)
			// Biom-an
			date, err = getAboveBiomass(antIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Biom-ma
			date, err = getAboveBiomass(harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// MaxLAI
			date, err = getMaxLAI(sowIndex, harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Wdrain
			date, _, err = getCumm(sowIndex, harvestIndex, "Recharge", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// CumET
			date, _, err = getCumm(sowIndex, harvestIndex, "Act_ET", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// SoilAvW
			date, err = getPlantAvailWater(harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Runoff
			date, _, err = getCumm(sowIndex, harvestIndex, "RunOff", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Transp
			_, actET, err := getCumm(sowIndex, harvestIndex, "Act_ET", &header, &content)
			if err != nil {
				return err
			}
			_, actEv, err := getCumm(sowIndex, harvestIndex, "Act_Ev", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(fmt.Sprintf("%.2f", actET-actEv))
			writer.WriteRune(sepeartor)
			// CroN-an
			date, err = getValueAt(antIndex, "AbBiomN", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// CroN-ma
			date, err = getValueAt(harvestIndex, "AbBiomN", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Nleac
			date, _, err = getCumm(sowIndex, harvestIndex, "NLeach", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// GrainN
			date, err = getNGrain(harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Nmin
			date, _, err = getCumm(sowIndex, harvestIndex, "NetNmin", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Nvol
			date, _, err = getCumm(sowIndex, harvestIndex, "NH3", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Nimmo
			writer.WriteString("na")
			writer.WriteRune(sepeartor)
			// SoilN
			date, err = getSoilMinN(harvestIndex, &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// Nden
			date, _, err = getCumm(sowIndex, harvestIndex, "Denit", &header, &content)
			if err != nil {
				return err
			}
			writer.WriteString(date)
			writer.WriteRune(sepeartor)
			// cumPARi
			writer.WriteString("na")
			writer.WriteString(newLine)
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

type cmdlargs struct {
	folderIn   string
	folderOut  string
	title      string
	model      string
	simulation string
	site       string
	filename   string
	modeller   string
	treatment  string
}

func readDailyOutputFile(filename string) (header []string, content [][]string, err error) {
	err = nil
	file, err := os.Open(filename)
	if err != nil {
		return header, content, err
	}
	defer file.Close()
	content = make([][]string, 0, 366)
	scanner := bufio.NewScanner(file)
	index := -1

	for scanner.Scan() {
		index++
		if index == 1 {
			header = strings.Fields(scanner.Text())
		}
		if index < 3 {
			continue
		}
		fields := strings.FieldsFunc(scanner.Text(), func(r rune) bool {
			if r == sepeartor {
				return true
			}
			return false
		})

		if len(fields) > 0 {
			content = append(content, fields)
		}
	}

	return header, content, err
}

// findIndex of column in input header
func findIndex(name string, arr *[]string) int {
	for i, val := range *arr {
		if val == name {
			return i
		}
	}
	return -1
}

// getStageStartDate get the row index and the date for the start day of a Stage
func getStageStartDate(stageID string, header *[]string, content *[][]string) (int, string, error) {

	date := na
	var err error
	index := -1
	indexStage := findIndex("Stage", header)
	if indexStage < 0 {
		return -1, "", fmt.Errorf("column Stage not found")
	}
	indexDate := findIndex("Date", header)
	if indexDate < 0 {
		return -1, "", fmt.Errorf("column Date not found")
	}

	oldDevStage := ""
	for rowIdx, rowVal := range *content {
		devStage := rowVal[indexStage]
		if devStage == stageID && oldDevStage != devStage {
			date = rowVal[indexDate]
			index = rowIdx
			return index, date, err
		}
		oldDevStage = devStage
	}

	return index, date, err
}

func getHarvestIndex(header *[]string, content *[][]string) (int, error) {

	indexStage := findIndex("Stage", header)
	if indexStage < 0 {
		return -1, fmt.Errorf("column Stage not found")
	}
	stage6Counter := 0
	olddevstage := "0"
	for rowIdx, rowVal := range *content {
		devStage := rowVal[indexStage]

		if devStage == "6" {
			// count days in stage6
			stage6Counter++
		}
		// harvest 3 days in, or at the end of stage 6, whatever comes first
		if stage6Counter >= 3 || (devStage == "0" && olddevstage != "0") {
			return rowIdx - 1, nil
		}
		olddevstage = devStage
	}
	return -1, nil
}

func getYield(harvestDateIndex int, header *[]string, content *[][]string) (string, error) {
	if harvestDateIndex == -1 {
		return "0.0", nil
	}
	indexYield := findIndex("Yield", header)
	if indexYield < 0 {
		return "", fmt.Errorf("column Yield not found")
	}

	yieldStr := (*content)[harvestDateIndex][indexYield]
	yield, err := strconv.ParseFloat(yieldStr, 64)
	if err != nil {
		return "", err
	}
	grainYield := yield / 1000.0 // kg/ha --> t/ha

	return fmt.Sprintf("%.2f", grainYield), nil
}

func getMaxLAI(sowingIndex, harvestIndex int, header *[]string, content *[][]string) (string, error) {

	if harvestIndex == -1 || sowingIndex == -1 {
		return "0.0", nil
	}
	indexLAI := findIndex("LAI", header)
	if indexLAI < 0 {
		return "", fmt.Errorf("column LAI not found")
	}
	laiMax := -1.0
	for rowIndex := sowingIndex; rowIndex <= harvestIndex; rowIndex++ {
		laiStr := (*content)[rowIndex][indexLAI]
		lai, err := strconv.ParseFloat(laiStr, 64)
		if err != nil {
			return "", err
		}
		if lai > laiMax {
			laiMax = lai
		}
	}
	return fmt.Sprintf("%.2f", laiMax), nil
}

func getAboveBiomass(rowIndex int, header *[]string, content *[][]string) (string, error) {
	if rowIndex == -1 {
		return "0.0", nil
	}
	indexAbBiom := findIndex("AbBiom", header)
	if indexAbBiom < 0 {
		return "", fmt.Errorf("column AbBiom not found")
	}
	val := (*content)[rowIndex][indexAbBiom]
	abbiom, err := strconv.ParseFloat(val, 64)
	if err != nil {
		return "", err
	}
	abbiom = abbiom / 1000.0 // kg/ha -->  t/ha
	return fmt.Sprintf("%.2f", abbiom), nil
}

// getValueAt  a row index for a certain column name
// the column needs to contain float or int values
func getValueAt(index int, colName string, header *[]string, content *[][]string) (string, error) {

	if index == -1 {
		return "0.0", nil
	}
	indexCol := findIndex(colName, header)
	if indexCol < 0 {
		return "", fmt.Errorf("column %s not found", colName)
	}
	val := (*content)[index][indexCol]
	valF, err := strconv.ParseFloat(val, 64)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%.2f", valF), nil
}

// getCumm accumulates float values from a row(eg sowingIndex) to a row (eg harvestIndex) (inclusive)
func getCumm(sowingIndex, harvestIndex int, colName string, header *[]string, content *[][]string) (string, float64, error) {
	if harvestIndex == -1 || sowingIndex == -1 {
		return "0.0", 0.0, nil
	}
	index := findIndex(colName, header)
	if index < 0 {
		return "", 0.0, fmt.Errorf("column %s not found", colName)
	}
	var cumm float64
	for rowIndex := sowingIndex; rowIndex <= harvestIndex; rowIndex++ {
		val := (*content)[rowIndex][index]
		valF, err := strconv.ParseFloat(val, 64)
		if err != nil {
			return "", 0.0, err
		}
		cumm = cumm + valF
	}
	return fmt.Sprintf("%.2f", cumm), cumm, nil
}

func getPlantAvailWater(harvestIndex int, header *[]string, content *[][]string) (string, error) {
	moisAccu := 0.0
	for layer := 1; layer <= auswaschungsTiefe; layer++ {
		key := "PASW_" + strconv.Itoa(layer)
		index := findIndex(key, header)
		mois := 0.0
		if index >= 0 {
			val := (*content)[harvestIndex][index]
			valF, err := strconv.ParseFloat(val, 64)
			if err != nil {
				return "", err
			}
			mois = valF * 1000.0 * 0.1 // m³/m³ --> mm
		}
		moisAccu = moisAccu + mois
	}
	return fmt.Sprintf("%.2f", moisAccu), nil
}

func getSoilMinN(harvestIndex int, header *[]string, content *[][]string) (string, error) {
	var nminAccu float64
	for layer := 1; layer <= auswaschungsTiefe; layer++ {
		keyNo3 := "NO3_" + strconv.Itoa(layer)
		keyNh4 := "NH4_" + strconv.Itoa(layer)
		indexno3 := findIndex(keyNo3, header)
		if indexno3 < 0 {
			return "", fmt.Errorf("column %s not found", keyNo3)
		}
		indexnh4 := findIndex(keyNh4, header)
		nh4 := 0.0
		if indexnh4 >= 0 {
			val := (*content)[harvestIndex][indexnh4]
			valF, err := strconv.ParseFloat(val, 64)
			if err != nil {
				return "", err
			}
			nh4 = valF * 0.1 // kg/m²
		}
		val := (*content)[harvestIndex][indexno3]
		valF, err := strconv.ParseFloat(val, 64)
		if err != nil {
			return "", err
		}
		no3 := valF * 0.1 // kg/m²
		nminAccu = nminAccu + no3 + nh4
	}

	nminAccu = nminAccu * 10000.0 // kg/m² --> kg/ha

	return fmt.Sprintf("%.2f", nminAccu), nil
}

func getNGrain(index int, header *[]string, content *[][]string) (string, error) {

	if index == -1 {
		return "0.0", nil
	}
	indexColYieldNc := findIndex("YieldNc", header)
	if indexColYieldNc < 0 {
		return "", fmt.Errorf("column %s not found", "YieldNc")
	}
	indexColOrgBiomFruit := findIndex("OrgBiom/Fruit", header)
	if indexColOrgBiomFruit < 0 {
		return "", fmt.Errorf("column %s not found", "OrgBiom/Fruit")
	}
	valOF := (*content)[index][indexColOrgBiomFruit]
	valOFf, err := strconv.ParseFloat(valOF, 64)
	if err != nil {
		return "", err
	}
	valYN := (*content)[index][indexColYieldNc]
	valYNf, err := strconv.ParseFloat(valYN, 64)
	if err != nil {
		return "", err
	}
	grainN := valYNf * valOFf

	return fmt.Sprintf("%.2f", grainN), nil
}
