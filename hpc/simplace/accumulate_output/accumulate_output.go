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
	//mergeTarBall := false
	argsWithoutExe := os.Args[1:]

	num := len(argsWithoutExe)
	for i, arg := range argsWithoutExe {
		if arg == "-infolder" && i+1 < num {
			inFolder = argsWithoutExe[i+1]
		}
		if arg == "-outfolder" && i+1 < num {
			outFolder = argsWithoutExe[i+1]
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

	listing := scanFiles(files, inFolder)

	baseFolderName := filepath.Base(inFolder)
	tarFileName := filepath.Join(outFolder, fmt.Sprintf("%s.tar", baseFolderName))
	err = os.MkdirAll(outFolder, os.ModePerm)
	if err != nil {
		log.Fatal(err)
	}

	merge := mergeTarGzipFile(tarFileName)
	var outFile *os.File
	var outWriter *tar.Writer

	excludes := make(map[string]bool)
	for internalPath, listOfTarGz := range listing {
		if len(listOfTarGz) > 1 {
			// make dir
			base := filepath.Base(internalPath)
			fullFileName := joinPath(outFolder, base)
			file, err := os.OpenFile(fullFileName, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
			if err != nil {
				log.Fatalf("Error occured while opening temp file: %s   \n", fullFileName)
			}
			for i, fileTarGz := range listOfTarGz {
				skippFirstLine := i != 0
				joinInternalFile(fileTarGz, internalPath, skippFirstLine, file)
			}
			outFile, outWriter = merge(internalPath, nil, fullFileName)
			file.Close()
			err = os.Remove(fullFileName)
			if err != nil {
				log.Printf("Failed to delete %v %v", fullFileName, err)
			}
			excludes[internalPath] = true
		}
	}
	for _, f := range files {
		fmt.Println(f.Name())
		// read file content into output files
		outFile, outWriter = merge("", excludes, filepath.Join(inFolder, f.Name()))
	}

	if outWriter != nil && outFile != nil {
		outWriter.Close()
		outFile.Close()

		reader, err := os.Open(tarFileName)
		if err != nil {
			log.Fatal(err)
		}
		tarFileNameBase := filepath.Base(tarFileName)
		gzTarget := filepath.Join(outFolder, fmt.Sprintf("%s.gz", tarFileNameBase))

		writer, err := os.Create(gzTarget)
		if err != nil {
			log.Fatal(err)
		}
		defer writer.Close()

		archiver := gzip.NewWriter(writer)
		archiver.Name = tarFileNameBase
		defer archiver.Close()

		_, err = io.Copy(archiver, reader)
		reader.Close()
		err = os.Remove(tarFileName)
		if err != nil {
			log.Printf("Failed to delete %v %v", tarFileName, err)
		}
	}

}

func joinInternalFile(tarGzInFile, internalFile string, skippFirstLine bool, tempFile *os.File) {

	f, err := os.Open(tarGzInFile)
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
			if header.Name == internalFile {
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
									_, ew := tempFile.Write(buf[index+1 : nr])
									if ew != nil {
										err = ew
										break
									}
								}
								if _, err := io.CopyBuffer(tempFile, tarReader, buf); err != nil {
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
					if _, err := io.Copy(tempFile, tarReader); err != nil {
						log.Fatal(err)
					}
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

func scanFiles(inputFiles ByLineNumber, inFolder string) (fileListing map[string][]string) {
	fileListing = make(map[string][]string)
	for _, ifile := range inputFiles {
		fmt.Println(ifile.Name())
		filename := filepath.Join(inFolder, ifile.Name())
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
				//fmt.Printf("Directory %s \n", header.Name)
				continue
			case tar.TypeReg:
				//fmt.Printf("Contents of %s %d %d\n", header.Name, header.Mode, header.Size)

				if _, ok := fileListing[header.Name]; ok {
					fileListing[header.Name] = append(fileListing[header.Name], filename)
				} else {
					fileListing[header.Name] = []string{filename}
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
	}
	return fileListing
}

func mergeTarGzipFile(targetFile string) func(string, map[string]bool, string) (*os.File, *tar.Writer) {
	tarfile, err := os.Create(targetFile)
	if err != nil {
		log.Fatal(err)
	}
	tarball := tar.NewWriter(tarfile)
	//dirLookup := make(map[string]bool)
	fileLookup := make(map[string]bool)
	return func(internalFilename string, excludes map[string]bool, filename string) (*os.File, *tar.Writer) {
		f, err := os.Open(filename)
		if err != nil {
			log.Fatal(err)
		}
		defer f.Close()
		if filepath.Ext(filename) != ".gz" {
			fileInfo, _ := f.Stat()
			hdr := &tar.Header{
				Name: internalFilename,
				Mode: 0600,
				Size: fileInfo.Size(),
			}
			if err := tarball.WriteHeader(hdr); err != nil {
				log.Fatal(err)
			}

			if _, err := io.Copy(tarball, f); err != nil {
				log.Fatal(err)
			}
		} else {
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
					// fmt.Printf("Directory %s \n", header.Name)
					// if !dirLookup[header.Name] {
					// 	dirLookup[header.Name] = true
					// 	tarball.WriteHeader(header)
					// }
					continue
				case tar.TypeReg:
					fmt.Printf("Contents of %s %d %d\n", header.Name, header.Mode, header.Size)
					if !excludes[header.Name] {
						if fileLookup[header.Name] {
							log.Fatalf("duplicated file '%s' in '%s'\n", header.Name, filename)
						}
						fileLookup[header.Name] = true
						tarball.WriteHeader(header)

						if _, err := io.Copy(tarball, tarReader); err != nil {
							log.Fatal(err)
						}
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
