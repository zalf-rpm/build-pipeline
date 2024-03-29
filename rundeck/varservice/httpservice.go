package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"

	"golang.org/x/crypto/ssh"
)

const dockerAPIURL string = "https://hub.docker.com"

var port uint64 = 6080
var sshKey []byte
var sshDefaultUserName string
var sshPassPhrase string

// main
// args optional: -sshkey Ssh/File/Path -sshuser defaultUser -port 6080
func main() {
	sshkeyPtr := flag.String("sshkey", "", "ssh key file path")
	sshuserPtr := flag.String("sshuser", "", "ssh user")
	sshphrasePtr := flag.String("sshphrase", "", "ssh phrase file path")
	portPtr := flag.Uint64("port", port, "ssh phrase file path")
	storePtr := flag.String("store", "", "passphase path")
	phrasePtr := flag.String("phrase", "", "passphase")

	flag.Parse()

	if len(*sshkeyPtr) > 0 {
		body, err := os.ReadFile(*sshkeyPtr)
		if err != nil {
			log.Fatal("ERROR: Failed to load ssh key")
			return
		}
		sshKey = body
	}
	if len(*sshphrasePtr) > 0 {
		body, err := os.ReadFile(*sshphrasePtr)
		if err != nil {
			log.Fatal("ERROR: Failed to load ssh pass phrase")
			return
		}
		sshPassPhrase = string(body)
	}

	sshDefaultUserName = *sshuserPtr
	port = *portPtr

	if len(*storePtr) > 0 && len(*phrasePtr) > 0 {
		println("varservice: store to file")
		err := os.WriteFile(*storePtr, []byte(*phrasePtr), os.ModePerm)
		if err != nil {
			println(err.Error)
			log.Fatal("ERROR: Failed to write pw file")
		}
		return
	}

	println("varservice started")
	http.HandleFunc("/rundeckvar/", rundeckVarHandler)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

// fetch docker tags, return them as json format string
// baseurl = e.g. https://hub.docker.com
// project = <user/organisation>/<image name>
func fetchDockerTags(project string, baseurl string) (string, error) {

	url := fmt.Sprintf("%s/v2/repositories/%s/tags?page_size=1000", baseurl, project)
	client := &http.Client{}
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	response, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer response.Body.Close()

	// get tags from result
	type Tags struct {
		Name string `json:"name"`
	}
	type ImageList struct {
		Result []Tags `json:"results"`
	}
	var content ImageList
	if err = json.NewDecoder(response.Body).Decode(&content); err != nil {
		return "", err
	}

	var tags []string
	for _, val := range content.Result {
		tags = append(tags, val.Name)
	}
	// special case for monica-cluster
	// find all tags that contain the word release and put them in front
	// remove all tags that do not start with a number or are less than major version 3
	if project == "zalfrpm/monica-cluster" {
		var releaseTags []string
		var otherTags []string
		for _, val := range tags {
			if strings.Contains(val, "release") {
				releaseTags = append(releaseTags, val)
			} else {
				// check if tag starts with a number
				majorVersion := strings.Split(val, ".")[0]
				if majorVersionInt, err := strconv.Atoi(majorVersion); err == nil {
					if majorVersionInt > 2 {
						otherTags = append(otherTags, val)
					}
				}
			}
		}
		tags = append(releaseTags, otherTags...)
	}
	// export to rundeck json format
	jsonText, err := json.Marshal(tags)
	if err != nil {
		return "", err
	}
	resultTags := string(jsonText)

	return resultTags, err
}

// remoteRun prepares a ssh session and executes what the remoteOperationHandler defines in that session
// user - ssh user name on the target operation system
// addr - url to remote machine
// privateKey - private Key - the target machine must have the corresponding public Key in authorized_keys
// params - parameter for remoteOperationHandler
// remoteOperationHandler - operation that uses the session
// returns a result string and error
func remoteRun(user string, addr string, privateKey []byte, passPhrase string, params interface{}, remoteOperationHandler func(*ssh.Session, interface{}) (string, error)) (string, error) {
	// Authentication
	var key ssh.Signer
	var err error
	if passPhrase != "" {
		key, err = ssh.ParsePrivateKeyWithPassphrase([]byte(privateKey), []byte(passPhrase))
	} else {
		key, err = ssh.ParsePrivateKey([]byte(privateKey))
	}
	if err != nil {
		return "", err
	}

	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(key),
		},
		//alternatively, you could use a password

		// Auth: []ssh.AuthMethod{
		// 	ssh.Password("debugpassword"),
		// },
		HostKeyCallback: ssh.InsecureIgnoreHostKey(),
	}
	// Connect
	client, err := ssh.Dial("tcp", addr+":22", config)
	if err != nil {
		return "", err
	}
	// Create a session. It is one session per command.
	session, err := client.NewSession()
	if err != nil {
		return "", err
	}
	defer session.Close()
	// exceute something on that session
	result, err := remoteOperationHandler(session, params)
	if err != nil {
		return "", err
	}
	return result, err
}

// analyseLoad - check load on a remote machine and return a estimation if it is desirable to spawn processes
// session - ssh session
// numnumCoresObj - number of required cores interface as int
func analyseLoad(session *ssh.Session, numCoresObj interface{}) (string, error) {

	numCoresRequired, ok := numCoresObj.(int)
	if !ok {
		return "", errors.New("invalid number of cores")
	}

	var b bytes.Buffer  // import "bytes"
	session.Stdout = &b // get output
	// commandline
	getAverageLoad := `sh -c 'uptime && lscpu'`
	err := session.Run(getAverageLoad)
	if err != nil {
		return "", err
	}
	// get output
	stdout := b.String()
	// parse number of cpu and average load
	var averageLoad float64
	var cpus int
	var hasCPU, hasUptime bool = false, false
	outLines := strings.Split(stdout, "\n")
	for _, valStr := range outLines {
		if strings.Contains(valStr, "load average: ") {
			averageLoad, err = parseUptime(valStr)
			if err != nil {
				return "", err
			}
			hasUptime = true
		}
		if strings.HasPrefix(valStr, "CPU(s):") {
			cpus, err = parseLscpu(valStr)
			if err != nil {
				return "", err
			}
			hasCPU = true
		}
	}
	if !hasCPU || !hasUptime {
		err = errors.New("not parsed")
		if err != nil {
			return "", err
		}
	}
	// create recommendation if node should be used for new processes
	recommendation := "(OK) recommended use"
	if averageLoad > float64(cpus) {
		recommendation = "(busy) high load - do not use"
	} else {
		if float64(numCoresRequired) > (float64(cpus) - averageLoad) {
			recommendation = "(slow) insufficient processing power"
		}
	}
	result := fmt.Sprintf(` %s(%.2f@%d)`, recommendation, averageLoad, cpus)

	return result, nil
}

type portRange struct {
	StartPort uint
	EndPort   uint
}

func validatePortRange(session *ssh.Session, portRangeObj interface{}) (string, error) {

	initialPortRange, ok := portRangeObj.(portRange)
	if !ok {
		return "", errors.New("invalid portRange type")
	}
	if initialPortRange.StartPort > initialPortRange.EndPort {
		return "", errors.New("invalid port range: start > end port")
	}
	if initialPortRange.StartPort > 65535 || initialPortRange.EndPort > 65535 {
		return "", errors.New("invalid port: port must be less than 65535")
	}
	var b bytes.Buffer  // import "bytes"
	session.Stderr = &b // get output
	// commandline scan ports
	getUsedPorts := fmt.Sprintf("nc -vz localhost %v-%v", initialPortRange.StartPort, initialPortRange.EndPort)
	err := session.Run(getUsedPorts)
	if err != nil {
		return "", err
	}
	// get output
	stdout := b.String()
	outLines := strings.Split(stdout, "\n")
	blockedPorts := make(map[uint]bool)
	for _, line := range outLines {
		token := strings.SplitAfter(line, "] ")
		if len(token) == 2 {
			token = strings.SplitAfter(token[1], " ")
			if len(token) > 1 {
				val, err := strconv.ParseUint(strings.Trim(token[0], " "), 10, 16)
				if err != nil {
					return "", err
				}
				port := uint(val)
				if port >= initialPortRange.StartPort && port <= initialPortRange.EndPort {
					blockedPorts[port] = false
				}
			}
		}
	}
	var resultArray []string
	for i := initialPortRange.StartPort; i <= initialPortRange.EndPort; i++ {
		if _, ok := blockedPorts[i]; !ok {
			resultArray = append(resultArray, fmt.Sprint(i))
		}
	}
	resultStr := strings.Join(resultArray, `","`)
	return resultStr, nil
}

// parseLscpu parse output of lscpu
func parseLscpu(lscpuOut string) (int, error) {

	numCPUline := strings.SplitAfter(lscpuOut, "CPU(s):")
	cpus, err := strconv.ParseInt(strings.Trim(numCPUline[1], " \n"), 10, 64)
	if err != nil {
		return -1, err
	}
	return int(cpus), nil
}

// parseUptime parse output of uptime
func parseUptime(uptimeOut string) (float64, error) {

	loadAvg := strings.SplitAfter(uptimeOut, "load average:")
	loadList := strings.Split(loadAvg[1], " ")
	var sumLoad float64
	var numLoad int
	var hasParsedSomething = false
	for _, valStr := range loadList {
		trimed := strings.Trim(valStr, ", \n")
		// normalize (possible german number format)
		normalized := strings.Replace(trimed, ",", ".", -1)
		val, err := strconv.ParseFloat(normalized, 64)
		if err == nil {
			sumLoad += val
			numLoad++
			hasParsedSomething = true
		}
	}
	if hasParsedSomething {
		sumLoad = sumLoad / float64(numLoad)
		return sumLoad, nil
	}
	err := errors.New("no values parsed")
	return 0, err
}

func extractClusterCredentials(value string) (string, string, error) {
	clusterID := value
	sshUserName := sshDefaultUserName
	if strings.Contains(clusterID, "/") {
		tokens := strings.Split(clusterID, "/")
		if len(tokens) != 2 || tokens[0] == "" || tokens[1] == "" {
			return "", "", errors.New("wrong cluster format - cluster=clusterName/sshUser expected")
		}
		sshUserName = tokens[1]
		clusterID = tokens[0]
	}
	return sshUserName, clusterID, nil
}

func rundeckVarHandler(w http.ResponseWriter, r *http.Request) {
	requestType := r.URL.Path[len("/rundeckvar/"):]
	w.Header().Set("Content-Type", "application/json")
	if strings.HasPrefix(requestType, "dockertags/") {
		dockerProject := r.URL.Path[len("/rundeckvar/dockertags/"):]
		taglist, err := fetchDockerTags(dockerProject, dockerAPIURL)
		if err != nil {
			fmt.Fprintf(w, `["ERROR"]`)
			return
		}
		fmt.Fprint(w, taglist)
		return
	} else if strings.HasPrefix(requestType, "clusterstatus") {
		coreValues, ok := r.URL.Query()["cores"]
		numCores := 1
		if ok && len(coreValues[0]) > 0 {
			val, err := strconv.ParseInt(coreValues[0], 10, 64)
			if err != nil {
				fmt.Fprintf(w, `["ERROR: cores should be a number"]`)
				return
			}
			numCores = int(val)
		}
		clusterValues, ok := r.URL.Query()["cluster"]
		if ok && len(clusterValues[0]) > 0 {

			outChan := make(chan string, 20)
			for _, val := range clusterValues {
				sshUserName, clusterID, err := extractClusterCredentials(val)
				if err != nil {
					fmt.Fprintf(w, `["ERROR: %s"]`, err)
					return
				}
				go sshWorker(outChan, sshUserName, clusterID, sshKey, numCores)
			}

			var cmdresults []string
			var collectedResults int
			for msg := range outChan {
				if collectedResults < len(clusterValues) {
					cmdresults = append(cmdresults, msg)
					collectedResults++
					if collectedResults == len(clusterValues) {
						close(outChan)
					}
				}
			}
			fmt.Fprintf(w, `{ %s }`, strings.Join(cmdresults, `, `))
			return
		}
	} else if strings.HasPrefix(requestType, "ports") {

		startports, startOk := r.URL.Query()["startport"]
		endports, endOk := r.URL.Query()["endport"]
		clusterIDs, clusterOk := r.URL.Query()["cluster"]
		if (startOk && len(startports[0]) > 0) &&
			(endOk && len(endports[0]) > 0) &&
			(clusterOk && len(clusterIDs[0]) > 0) {
			sshUserName, clusterID, err := extractClusterCredentials(clusterIDs[0])
			if err != nil {
				fmt.Fprintf(w, `["ERROR:  failed to read credentials"]`)
				return
			}
			var ports portRange
			startport, err := strconv.ParseUint(startports[0], 10, 64)
			if err != nil {
				fmt.Fprintf(w, `["ERROR:  start port not a number"]`)
				return
			}
			ports.StartPort = uint(startport)

			endport, err := strconv.ParseUint(endports[0], 10, 64)
			if err != nil {
				fmt.Fprintf(w, `["ERROR:  end port not a number"]`)
				return
			}
			ports.EndPort = uint(endport)

			cmdresult, err := remoteRun(sshUserName, clusterID, sshKey, sshPassPhrase, ports, validatePortRange)
			if err != nil {
				serr := strings.Replace(err.Error(), `"`, "'", -1)
				fmt.Fprintf(w, `["Error: %s "]`, serr)
				return
			}
			fmt.Fprintf(w, `["%s"]`, cmdresult)
			return
		}
	} else if strings.HasPrefix(requestType, "listdockercontainer") {
		pattern, patternOk := r.URL.Query()["pattern"]
		clusterIDs, clusterOk := r.URL.Query()["cluster"]
		if patternOk && len(pattern[0]) > 0 &&
			clusterOk && len(clusterIDs[0]) > 0 {

			sshUserName, clusterID, err := extractClusterCredentials(clusterIDs[0])
			if err != nil {
				fmt.Fprintf(w, `["ERROR:  failed to read credentials"]`)
				return
			}
			cmdresult, err := remoteRun(sshUserName, clusterID, sshKey, sshPassPhrase, pattern[0], listDockerImages)
			if err != nil {
				serr := strings.Replace(err.Error(), `"`, "'", -1)
				fmt.Fprintf(w, `["Error: %s "]`, serr)
				return
			}
			fmt.Fprintf(w, `["%s"]`, cmdresult)
			return
		}
	}

	fmt.Fprintf(w, `["INVALID PARAMETER"]`)
}

func listDockerImages(session *ssh.Session, pattern interface{}) (string, error) {

	imagePattern, ok := pattern.(string)
	if !ok {
		return "", errors.New("invalid pattern")
	}
	var b bytes.Buffer  // import "bytes"
	session.Stdout = &b // get output
	// commandline list docker container
	var listDockerContainer string
	if imagePattern == "all" {
		listDockerContainer = `docker ps --format "{{.Image}}; {{.Names}}"`
	} else {
		listDockerContainer = fmt.Sprintf(`docker ps --format "{{.Image}}; {{.Names}}" | grep %s`, imagePattern)
	}

	err := session.Run(listDockerContainer)
	if err != nil {
		// process returns error if nothing is found
		return "none", nil
	}
	// get output
	stdout := b.String()
	var resultList []string
	lines := strings.Split(stdout, "\n")
	for _, line := range lines {
		tokens := strings.Split(line, ";")
		if len(tokens) > 1 {
			resultList = append(resultList, strings.TrimSpace(tokens[1]))
		}

	}

	return strings.Join(resultList, `", "`), nil
}

// concurrent worker for ssh remote run
func sshWorker(c chan<- string, user string, clusterID string, sshKey []byte, requestedNumCores int) {
	cmdresult, err := remoteRun(user, clusterID, sshKey, sshPassPhrase, requestedNumCores, analyseLoad)
	if err != nil {
		cmdresult = err.Error()
		c <- cmdresult
		return
	}

	cmdresult = fmt.Sprintf(`"%s": "%s"`, clusterID+cmdresult, clusterID)
	c <- cmdresult
}
