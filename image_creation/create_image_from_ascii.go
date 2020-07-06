package main

import (
	"bufio"
	"compress/gzip"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"gonum.org/v1/plot"
	"gonum.org/v1/plot/palette/moreland"
	"gonum.org/v1/plot/plotter"
	"gonum.org/v1/plot/vg"

	"gopkg.in/yaml.v2"
)

func main() {

	PATHS := map[string]map[string]string{
		"local": {
			"sourcepath": "./asciigrids_debug/",
			"outputpath": ".",
			"png-out":    "png_debug/",
			"pdf-out":    "pdf-out_debug/",
		},
		"test": {
			"sourcepath": "./asciigrid/",
			"outputpath": "./testout/",
			"png-out":    "png2/",
			"pdf-out":    "pdf-out2/",
		},
		"cluster": {
			"sourcepath": "/source/",
			"outputpath": "/out/",
			"png-out":    "png/",
			"pdf-out":    "pdf-out/",
		},
	}

	USER := "local"
	//NONEVALUE := -9999

	pathPtr := flag.String("path", USER, "path id")
	sourcePtr := flag.String("source", "", "path to source folder")
	outPtr := flag.String("output", "", "path to out folder")

	flag.Parse()

	pathID := *pathPtr
	sourceFolder := *sourcePtr
	outputFolder := *outPtr

	if len(sourceFolder) == 0 {
		sourceFolder = PATHS[pathID]["sourcepath"]
	}
	if len(outputFolder) == 0 {
		outputFolder = PATHS[pathID]["outputpath"]
	}

	pngFolder := filepath.Join(outputFolder, PATHS[pathID]["png-out"])
	pdfFolder := filepath.Join(outputFolder, PATHS[pathID]["pdf-out"])

	build(sourceFolder, pngFolder, pdfFolder)

}
func build(sourceFolder, pngFolder, pdfFolder string) {

	err := filepath.Walk(sourceFolder, func(path string, info os.FileInfo, err error) error {

		if err != nil {
			fmt.Printf("prevent panic by handling failure accessing a path %q: %v\n", path, err)
			return err
		}
		if info.IsDir() {
			dirContent := make([]string, 0, 10)
			d, err := os.Open(path)
			if err != nil {
				return err
			}
			defer d.Close()
			names, err := d.Readdir(-1)
			if err != nil {
				return err
			}
			for _, name := range names {
				if !name.IsDir() && (strings.HasSuffix(name.Name(), ".asc") || strings.HasSuffix(name.Name(), ".asc.gz")) {
					dirContent = append(dirContent, name.Name())
				}
			}
			if len(dirContent) > 0 {
				scenario := filepath.Base(path)
				pdfpath := filepath.Join(pdfFolder, fmt.Sprintf("scenario_%s.pdf", scenario))
				makeDir(pdfpath)
				pdf := pdfpath //TODO PdfPages(pdfpath)
				sort.Strings(dirContent)

				for _, file := range dirContent {
					end := len(file)

					pngfilename := file[:end-3] + "png"
					metafilename := file + ".meta"
					isGZ := strings.HasSuffix(file, ".gz")
					if isGZ {
						pngfilename = file[:end-6] + "png"
						metafilename = file[:end-2] + "meta"
					}
					metapath := filepath.Join(path, metafilename)
					outpath := filepath.Join(pngFolder, scenario, pngfilename)
					filename := filepath.Join(path, file)
					createImgFromMeta(filename, metapath, outpath, pdf)
				}

			}
		}
		return nil
	})
	if err != nil {
		fmt.Printf("error walking the path %q: %v\n", sourceFolder, err)
		return
	}

}
func createImgFromMeta(asciipath, metapath, outpath, pdf string) error {

	makeDir(outpath)
	asciifile, err := os.Open(asciipath)
	if err != nil {
		return err
	}
	defer asciifile.Close()

	var reader io.Reader
	if strings.HasSuffix(asciipath, ".gz") {
		// Read in ascii header data
		reader, err = gzip.NewReader(asciifile)
		if err != nil {
			return err
		}
	} else {
		// Read in ascii header data
		reader = asciifile
	}
	scanner := bufio.NewScanner(reader)
	numHeader := 6
	var asciiHeader [6]string
	for index := 0; index < numHeader; index++ {
		if ok := scanner.Scan(); ok {
			line := scanner.Text()
			asciiHeader[index] = strings.Fields(line)[1]
		} else {
			return errors.New("invalid file format")
		}
	}

	// Read the ASCII raster header
	ascciCols, _ := strconv.ParseInt(asciiHeader[0], 10, 64)
	asciiRows, _ := strconv.ParseInt(asciiHeader[1], 10, 64)
	asciiXll, _ := strconv.ParseFloat(asciiHeader[2], 64)
	asciiYll, _ := strconv.ParseFloat(asciiHeader[3], 64)
	asciiCs, _ := strconv.ParseFloat(asciiHeader[4], 64)
	asciiNodata, _ := strconv.ParseFloat(asciiHeader[5], 64)
	asciiNodataStr := asciiHeader[5]

	var grid asciiTable
	grid.colLen = int(ascciCols)
	grid.rowLen = int(asciiRows)
	grid.minX = asciiXll
	grid.minY = asciiYll
	grid.resolution = asciiCs
	grid.grid = make([][]float64, grid.rowLen, grid.rowLen)
	for row := asciiRows - 1; row >= 0; row-- {
		if ok := scanner.Scan(); ok {
			grid.grid[row] = make([]float64, ascciCols)
			line := scanner.Text()
			tokens := strings.Fields(line)
			index := -1
			for _, token := range tokens {
				index++
				if asciiNodataStr != token {
					val, err := strconv.ParseInt(token, 10, 64)
					if err != nil {
						return err
					}
					grid.grid[row][index] = float64(val)
				} else {
					grid.grid[row][index] = math.NaN()
				}
			}

		} else {
			// grid.rowLen = len(grid.grid)
			// grid.colLen = len(grid.grid[0])
			// break
			return errors.New("not enough rows")
		}
	}
	conf := metaConfig{
		colormap: "viridis",
		factor:   0.001,
		maxValue: asciiNodata,
		minValue: asciiNodata,
	}

	bytedata, err := ioutil.ReadFile(metapath)
	if err != nil {
		return err
	}

	err = yaml.Unmarshal(bytedata, &conf)
	if err != nil {
		log.Fatalf("error: %v", err)
	}
	pal := moreland.SmoothBlueRed().Palette(255)
	heatmap := plotter.NewHeatMap(grid, pal)
	p, err := plot.New()
	if err != nil {
		panic(err)
	}
	p.Title.Text = conf.title
	p.Add(heatmap)
	//p.X.Padding = 0
	//p.Y.Padding = 0

	w := 400
	div := grid.colLen / w
	// if err := p.Save(vg.Length(grid.colLen/div), vg.Length(grid.rowLen/div), outpath); err != nil {
	// 	return err
	// }

	grid.minX = 0
	grid.minY = 0
	grid.resolution = 1

	hm := plotter.NewHeatMap(grid, pal)
	pTest, err := plot.New()
	if err != nil {
		panic(err)
	}
	pTest.Title.Text = "test"
	pTest.Add(hm)
	//.svg
	if err := pTest.Save(vg.Length(grid.colLen/div), vg.Length(grid.rowLen/div), pdf+".svg"); err != nil {
		return err
	}

	return nil
}

// asciiTable implement interface GridXYZ
type asciiTable struct {
	grid       [][]float64
	colLen     int
	rowLen     int
	resolution float64
	minX       float64
	minY       float64
}

// Dims returns the dimensions of the grid.
func (p asciiTable) Dims() (c, r int) {
	return p.colLen, p.rowLen
}

// X returns the coordinate for the column at the index c.
// It will panic if c is out of bounds for the grid.
func (p asciiTable) X(c int) float64 {
	return p.minX + float64(c)*p.resolution
}

// Y returns the coordinate for the row at the index r.
// It will panic if r is out of bounds for the grid.
func (p asciiTable) Y(r int) float64 {
	return p.minY + float64(r)*p.resolution
}

// Z returns the value of a grid value at (c, r).
// It will panic if c or r are out of bounds for the grid.
func (p asciiTable) Z(c, r int) float64 {
	return p.grid[r][c]
}

type metaConfig struct {
	title     string    `yaml:"title,omitempty"`
	labeltext string    `yaml:"labeltext,omitempty"`
	factor    float64   `yaml:"factor,omitempty"`
	maxValue  float64   `yaml:"maxValue,omitempty"`
	minValue  float64   `yaml:"minValue,omitempty"`
	colormap  string    `yaml:"colormap,omitempty"`
	colorlist []string  `yaml:"colorlist,omitempty"`
	cbarLabel []string  `yaml:"cbarLabel,omitempty"`
	ticklist  []float64 `yaml:"ticklist,omitempty"`
}

func makeDir(outPath string) {
	dir := filepath.Dir(outPath)
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if err := os.MkdirAll(dir, os.ModePerm); err != nil {
			log.Fatalf("ERROR: Failed to generate output path %s :%v", dir, err)
		}
	}
}
