package main

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// accumulate each file, with the same filename
func main() {

	inFolder := "/home/user/project/out"
	outFolder := "/home/user/project/sum_out"
	mergeTarBall := false
	argsWithoutExe := os.Args[1:]

	num := len(argsWithoutExe)
	for i, arg := range argsWithoutExe {
		if arg == "-infolder" && i+1 < num {
			inFolder = argsWithoutExe[i+1]
		}
		if arg == "-outfolder" && i+1 < num {
			outFolder = argsWithoutExe[i+1]
		}
		if arg == "-mergetarball" {
			mergeTarBall = true
		}
	}
	fmt.Printf("In: %s\n", inFolder)
	fmt.Printf("Out: %s\n", outFolder)
	// scann infolder and get list of files
	var files ByLineNumber
	files, err := ioutil.ReadDir(inFolder)
	if err != nil {
		log.Fatal(err)
	}
	// sort by line numbers
	fmt.Println("Sorted:")
	sort.Sort(files)
	if mergeTarBall {
		baseFolderName := filepath.Base(inFolder)
		tarFile := filepath.Join(outFolder, fmt.Sprintf("%s.tar", baseFolderName))
		err = os.MkdirAll(outFolder, os.ModePerm)
		if err != nil {
			log.Fatal(err)
		}

		merge := mergeTarGzipFile(tarFile)
		var outFile *os.File
		var outWriter *tar.Writer
		for _, f := range files {
			fmt.Println(f.Name())
			// read file content into output files
			outFile, outWriter = merge(filepath.Join(inFolder, f.Name()))
		}
		if outWriter != nil && outFile != nil {
			outWriter.Close()
			outFile.Close()

			reader, err := os.Open(tarFile)
			if err != nil {
				log.Fatal(err)
			}
			tarFileName := filepath.Base(tarFile)
			gzTarget := filepath.Join(outFolder, fmt.Sprintf("%s.gz", tarFileName))

			writer, err := os.Create(gzTarget)
			if err != nil {
				log.Fatal(err)
			}
			defer writer.Close()

			archiver := gzip.NewWriter(writer)
			archiver.Name = tarFileName
			defer archiver.Close()

			_, err = io.Copy(archiver, reader)
		}

	} else {
		for _, f := range files {
			fmt.Println(f.Name())
			// read file content into output files
			readTarGzipFile(inFolder+"/"+f.Name(), outFolder)
		}
	}

}

func readTarGzipFile(filename string, outPath string) {

	f, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	// open gzip reader
	gzf, err := gzip.NewReader(f)
	if err != nil {
		log.Fatal(err)
	}
	// open tar reader
	tarReader := tar.NewReader(gzf)

	// read file entries from tar
	for {
		header, err := tarReader.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatal(err)
		}

		name := header.Name

		switch header.Typeflag {
		case tar.TypeDir:
			fmt.Printf("Directory %s \n", header.Name)
			continue
		case tar.TypeReg:
			fmt.Printf("Contents of %s %d %d\n", header.Name, header.Mode, header.Size)
			filePath := header.Name
			// make dir
			fullFileName := joinPath(outPath, filePath)
			fullFilePath := path.Dir(fullFileName)
			err = os.MkdirAll(fullFilePath, os.ModePerm)
			if err != nil {
				log.Fatal(err)
			}
			skippFirstLine := false
			// append content to output file
			if _, err := os.Stat(fullFileName); err == nil {
				skippFirstLine = true
			} else if os.IsNotExist(err) {
				skippFirstLine = false
			} else {
				log.Fatal(err)
			}

			file, err := os.OpenFile(fullFileName, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
			if err != nil {
				log.Fatalf("Error occured while opening result file: %s   \n", filePath)
			}
			defer file.Close()

			if skippFirstLine {
				lineSep := []byte{'\n'}
				size := 32 * 1024
				buf := make([]byte, size)
				for {
					nr, er := tarReader.Read(buf)
					if nr > 0 {
						index := bytes.Index(buf[:nr], lineSep)
						if index != -1 {
							if index+1 < nr {
								_, ew := file.Write(buf[index+1 : nr])
								if ew != nil {
									err = ew
									break
								}
							}
							if _, err := io.CopyBuffer(file, tarReader, buf); err != nil {
								log.Fatal(err)
							}
							break
						}
					}
					if er != nil {
						if er != io.EOF {
							err = er
						}
						break
					}
				}
			} else {
				if _, err := io.Copy(file, tarReader); err != nil {
					log.Fatal(err)
				}
			}
		default:
			fmt.Printf("%s : %c %s %s\n",
				"Unable to figure out type",
				header.Typeflag,
				"in file",
				name,
			)
		}
	}

}

func mergeTarGzipFile(targetFile string) func(string) (*os.File, *tar.Writer) {
	tarfile, err := os.Create(targetFile)
	if err != nil {
		log.Fatal(err)
	}
	tarball := tar.NewWriter(tarfile)
	dirLookup := make(map[string]bool)
	fileLookup := make(map[string]bool)
	return func(filename string) (*os.File, *tar.Writer) {
		f, err := os.Open(filename)
		if err != nil {
			log.Fatal(err)
		}
		defer f.Close()

		// open gzip reader
		gzf, err := gzip.NewReader(f)
		if err != nil {
			log.Fatal(err)
		}
		// open tar reader
		tarReader := tar.NewReader(gzf)

		// read file entries from tar
		for {
			header, err := tarReader.Next()
			if err == io.EOF {
				break
			}
			if err != nil {
				log.Fatal(err)
			}

			switch header.Typeflag {
			case tar.TypeDir:
				fmt.Printf("Directory %s \n", header.Name)
				if !dirLookup[header.Name] {
					dirLookup[header.Name] = true
					tarball.WriteHeader(header)
				}
				continue
			case tar.TypeReg:
				fmt.Printf("Contents of %s %d %d\n", header.Name, header.Mode, header.Size)
				if fileLookup[header.Name] {
					log.Fatalf("duplicated file '%s' in '%s'\n", header.Name, filename)
				}
				fileLookup[header.Name] = true
				tarball.WriteHeader(header)

				if _, err := io.Copy(tarball, tarReader); err != nil {
					log.Fatal(err)
				}

			default:
				fmt.Printf("%s : %c %s %s\n",
					"Unable to figure out type",
					header.Typeflag,
					"in file",
					header.Name,
				)
			}
		}
		return tarfile, tarball
	}
}

// ByLineNumber implements sort.Interface for []os.FileInfo based on
// the line number in the Name field.
type ByLineNumber []os.FileInfo

func (a ByLineNumber) Len() int      { return len(a) }
func (a ByLineNumber) Swap(i, j int) { a[i], a[j] = a[j], a[i] }
func (a ByLineNumber) Less(i, j int) bool {
	splittedI := strings.FieldsFunc(a[i].Name(), func(r rune) bool { return r == '_' })
	splittedJ := strings.FieldsFunc(a[j].Name(), func(r rune) bool { return r == '_' })
	var numberI int64
	var numberJ int64
	for indexI := 4; indexI < len(splittedI); indexI++ {
		match, _ := regexp.MatchString(`^\d+-\d+$`, splittedI[indexI])
		if match {
			num, err := strconv.ParseInt(strings.Split(splittedI[indexI], "-")[0], 10, 64)
			if err != nil {
				log.Fatal(err)
			}
			numberI = num
		}
	}
	for indexJ := 4; indexJ < len(splittedJ); indexJ++ {
		match, _ := regexp.MatchString(`^\d+-\d+$`, splittedJ[indexJ])
		if match {
			num, err := strconv.ParseInt(strings.Split(splittedJ[indexJ], "-")[0], 10, 64)
			if err != nil {
				log.Fatal(err)
			}
			numberJ = num
		}
	}

	return numberI < numberJ
}

// joinPath with zip slip attack check
func joinPath(outputFolder, filePath string) (result string) {
	result = filepath.Join(outputFolder, filePath)
	if !strings.HasPrefix(result, filepath.Clean(outputFolder)+string(os.PathSeparator)) {
		log.Fatalf("%s: illegal file path", filePath)
	}
	return result
}
