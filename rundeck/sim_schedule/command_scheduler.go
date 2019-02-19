package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

var concurrentOperations uint16 = 10 // number of paralell processes
var childProcessTimeout = 2          // timeout in minutes

func main() {

	var call string
	var containerName string
	var dockerImage string
	var dockerParameters []string
	var configLines []string
	var workingDir string
	var numberOfLines = -1

	fmt.Println("Model execution schedular")
	var dockerParameterMode = false
	// read command line args
	argsWithoutProg := os.Args[1:]
	for i, arg := range argsWithoutProg {

		if dockerParameterMode {
			// when -dockerparameter was called any following parameter will be interpreted as a parameter for docker
			parameterStr := argsWithoutProg[i]
			parameterStr = strings.TrimLeft(parameterStr, `" `)
			parameterStr = strings.TrimRight(parameterStr, ` "`)
			dockerParameters = append(dockerParameters, strings.Fields(parameterStr)...)
		}
		if arg == "-help" {
			// print help and terminate
			printHelp()
			return
		}
		if arg == "-setup" && i+1 < len(argsWithoutProg) {
			// read setup file
			setupFilename := argsWithoutProg[i+1]
			file, err := os.Open(setupFilename)
			if err != nil {
				log.Fatal(err)
			}
			defer file.Close()
			scanner := bufio.NewScanner(file)
			for scanner.Scan() {
				line := scanner.Text()
				configLines = append(configLines, line)
			}
			if err := scanner.Err(); err != nil {
				log.Fatal(err)
			}
			path, _ := filepath.Abs(file.Name())
			workingDir = filepath.Dir(path)
		}
		if arg == "-concurrent" && i+1 < len(argsWithoutProg) {
			cOps, err := strconv.ParseUint(argsWithoutProg[i+1], 10, 64)
			if err != nil {
				log.Fatal("ERROR: Failed to parse number of concurrent runs")
				return
			}
			concurrentOperations = uint16(cOps)
		}
		if arg == "-image" && i+1 < len(argsWithoutProg) {
			// -docker image zalfrpm/wineforhermes:latest
			dockerImage = argsWithoutProg[i+1]
		}
		if arg == "-call" && i+1 < len(argsWithoutProg) {
			// call into the image
			// xvfb-run -a wine "$CMD"
			call = argsWithoutProg[i+1]
		}
		if arg == "-numlines" && i+1 < len(argsWithoutProg) {
			// evaluate the first n lines only (optional)
			numLines, err := strconv.ParseInt(argsWithoutProg[i+1], 10, 64)
			if err != nil {
				log.Fatal("ERROR: Failed to parse number of lines")
				return
			}
			numberOfLines = int(numLines)
		}
		if arg == "-containername" && i+1 < len(argsWithoutProg) {
			// myContainerName parameter (optional)
			containerName = "--name=" + argsWithoutProg[i+1]
		}
		if arg == "-dockerparameter" && i+1 < len(argsWithoutProg) {
			// -v $STORAGE_VOLUME:$IMAGE_STORAGE etc
			dockerParameterMode = true
		}
		if arg == "-timeout" && i+1 < len(argsWithoutProg) {
			timeout, err := strconv.ParseUint(argsWithoutProg[i+1], 10, 64)
			if err != nil {
				log.Fatal("ERROR: Failed to parse timeout")
				return
			}
			childProcessTimeout = int(timeout)
		}
	}
	// start active runs for number of concurrentOperations
	// when an active run is finished, start a follow up run
	logOutputChan := make(chan string)
	resultChannel := make(chan string)
	var activeRuns uint16
	errorSummary := checkResultForError()
	var errorSummaryResult []string
	for i, line := range configLines {
		if numberOfLines > 0 && i >= numberOfLines {
			// if number of lines is set and limit is reached
			break
		}
		for activeRuns == concurrentOperations {
			select {
			case result := <-resultChannel:
				activeRuns--
				errorSummaryResult = errorSummary(result, configLines)
				fmt.Println(result)
			case log := <-logOutputChan:
				fmt.Println(log)
			}
		}

		if activeRuns < concurrentOperations {
			activeRuns++
			var nextContainerName string
			if len(containerName) > 0 {
				nextContainerName = containerName + fmt.Sprint(i)
			}
			commandLine := line
			if len(call) > 0 {
				commandLine = call + " " + line
			}
			logID := fmt.Sprintf("[%v]", i)
			go startInDocker(workingDir, dockerImage, nextContainerName, commandLine, logID, dockerParameters, resultChannel, logOutputChan, childProcessTimeout)
		}
	}
	// fetch output of last runs
	for activeRuns > 0 {
		select {
		case result := <-resultChannel:
			activeRuns--
			errorSummaryResult = errorSummary(result, configLines)
			fmt.Println(result)
		case log := <-logOutputChan:
			fmt.Println(log)
		}
	}
	var numErr int
	for _, line := range errorSummaryResult {
		fmt.Println(line)
		numErr++
	}

	fmt.Printf("Number of errors: %v \n", numErr-1)
}

// printHelp prints the valid command line parameter and their usage
func printHelp() {
	fmt.Println(`-setup            newline seperated file with command line args`)
	fmt.Println(`-concurrent       (optional) number of concurrent docker container`)
	fmt.Println(`-user             userid and group id e.g. "$(id -u):$(id -g)"`)
	fmt.Println(`-image            docker image <user>/<image>:<tag> e.g "zalfrpm/wineforhermes:latest"`)
	fmt.Println(`-call             call into docker containter to launch the model`)
	fmt.Println(`-containername    base name for launched containers`)
	fmt.Println(`-dockerParameters !!!must be last!!! all following parameters will be treated as docker parameters`)
	fmt.Println(`-timeout          timeout for child process in minutes`)
	fmt.Println(`-numlines         (optional) execute only the first n lines`)
}
func checkResultForError() func(string, []string) []string {
	var errSummary = []string{"Error Summary:"}
	return func(result string, configLines []string) []string {
		if !strings.HasSuffix(result, "Success") {
			if strings.HasSuffix(result, "timeout") {
				numStr := strings.Trim(result, "[]timeout")
				fmt.Printf("LogId %v \n", numStr)
				lineNumber, _ := strconv.ParseInt(numStr, 10, 64)
				fmt.Printf("LogId parsed %v \n", lineNumber)
				errSummary = append(errSummary, result+": "+configLines[int(lineNumber)])
				fmt.Println(errSummary)
			} else {
				errSummary = append(errSummary, result)
			}
		}
		return errSummary
	}
}

// startInDocker runs a docker image with a commandline (or for debug a programm) and sends the log output back into a channel.
// Setup timeout a timeout for programms that may get stuck.
func startInDocker(workingDir, image, containername, cmdline, logID string, dockerParameters []string, out, logout chan<- string, timeoutMinutes int) {

	// docker run --user $(id -u):$(id -g) --rm -v $STORAGE_VOLUME:$IMAGE_STORAGE --name=$CONTAINER_NAME zalfrpm/wineforhermes:$VERSION "$CMD"

	// create command
	var cmd *exec.Cmd
	if len(image) > 0 {
		// create docker command
		dockerArgs := []string{"run", "--rm", containername}
		dockerArgs = append(dockerArgs, dockerParameters...)
		dockerArgs = append(dockerArgs, image)
		dockerArgs = append(dockerArgs, strings.Fields(cmdline)...)

		logout <- fmt.Sprint(logID + strings.Join(dockerArgs, " "))
		cmd = exec.Command("docker", dockerArgs...)
	} else {
		// test: create for command
		args := strings.Fields(cmdline)
		logout <- fmt.Sprint(logID + workingDir + "/" + args[0] + " " + strings.Join(args[1:], " "))

		cmd = exec.Command(workingDir+"/"+args[0], args[1:]...)
		cmd.Dir = workingDir
	}

	// create output pipe
	cmdOut, err := cmd.StdoutPipe()
	if err != nil {
		cmdresult := fmt.Sprintf(`%s Process failed to generate out pipe: %s`, logID, err)
		out <- cmdresult
		return
	}
	// run command
	err = cmd.Start()
	if err != nil {
		cmdresult := fmt.Sprintf(`%s Process failed to start: %s`, logID, err)
		out <- cmdresult
		return
	}
	// scan for output
	outScanner := bufio.NewScanner(cmdOut)
	outScanner.Split(bufio.ScanLines)
	c1 := make(chan bool, 1)
	go func() {
		for outScanner.Scan() {
			text := outScanner.Text()
			logout <- logID + text
			fmt.Println(text)
			c1 <- true
		}
		c1 <- false
	}()
	// start timer for timeout
	timer := time.NewTimer(time.Duration(timeoutMinutes) * time.Minute)
	// read output, while programm is running, or run in timeout if no output is received
	for stillRunning := true; stillRunning; {
		select {
		case stillRunning = <-c1:
			if stillRunning {
				timer.Reset(time.Duration(timeoutMinutes) * time.Minute)
			}
		case <-timer.C:
			cmdresult := logID + "timeout"
			out <- cmdresult
			if len(image) > 0 {
				stopDockerContainer(containername)
			}
			return
		}
	}
	// wait until programm is finished
	err = cmd.Wait()
	if err != nil {
		cmdresult := fmt.Sprintf(`%s Execution failed with error: %s`, logID, err)
		out <- cmdresult
		return
	}

	cmdresult := logID + "Success"
	out <- cmdresult
}

func stopDockerContainer(name string) {
	cmd := exec.Command("docker", "stop", name)
	err := cmd.Run()
	if err != nil {
		println("Failed to stop docker container " + name)
	}
}
